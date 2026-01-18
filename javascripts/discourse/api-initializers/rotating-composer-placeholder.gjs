import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.0", (api) => {
  const FALLBACK = ["Write your reply…"];

  function pickRandom(arr) {
    return arr[Math.floor(Math.random() * arr.length)];
  }

  // Find the editor input once the composer is actually in the DOM
  function findEditorElement() {
    const root = document.querySelector(".d-editor");
    if (!root) return null;

    const textarea = root.querySelector("textarea.d-editor-input");
    if (textarea) return { kind: "textarea", el: textarea, root };

    const rich = root.querySelector(".ProseMirror.d-editor-input[contenteditable='true']");
    if (rich) return { kind: "rich", el: rich, root };

    return null;
  }


  function setComposerPlaceholder(text) {
    const found = findEditorElement();
    if (!found) return false;

    if (found.kind === "textarea") {
      found.el.setAttribute("placeholder", text);
      return true;
    }

    // Rich editor (ProseMirror)
    // 1) Update the <p data-placeholder="..."> node that ProseMirror uses
    const p = found.el.querySelector("p[data-placeholder]") || found.el.querySelector("p");
    if (p) {
      p.setAttribute("data-placeholder", text);
    }
  
    // 2) Also keep accessibility label up to date
    found.el.setAttribute("aria-label", text);

    return true;
  }



  // Keep retries as a fallback, but with composer:inserted we usually don't need many
  function setComposerPlaceholderWithRetries(text) {
    let tries = 0;
    const maxTries = 15;
    const delayMs = 80;

    const attempt = () => {
      tries += 1;

      const ok = setComposerPlaceholder(text);

      // eslint-disable-next-line no-console
      console.log(
        `[rotating-composer-placeholder] try ${tries} ok=${ok} hasComposer=${!!document.querySelector(".composer")}`
      );


      if (ok) return;
      if (tries < maxTries) setTimeout(attempt, delayMs);
    };

    attempt();

    // extra “win” passes in case the editor re-renders shortly after insertion
    setTimeout(() => setComposerPlaceholder(text), 250);
    setTimeout(() => setComposerPlaceholder(text), 800);
  }

  function normalizePlaceholders(value) {
    if (Array.isArray(value)) {
      return value.map((v) => String(v).trim()).filter(Boolean);
    }

    if (typeof value === "string") {
      return value
        .split(/\r?\n|,|\|/g) // newline, comma, or pipe
        .map((s) => s.trim())
        .filter(Boolean);
    }

    return [];
  }

  function getPlaceholdersFromSettings() {
    const raw = normalizePlaceholders(settings?.rotating_placeholders);
    return raw.length ? raw : FALLBACK;
  }

  function applyRandomPlaceholder() {
    const placeholders = getPlaceholdersFromSettings();
    setComposerPlaceholderWithRetries(pickRandom(placeholders));

    // eslint-disable-next-line no-console
    console.log(
      "[rotating-composer-placeholder] applied, settings:",
      settings?.rotating_placeholders
    );
  }

  // IMPORTANT: composer:opened can fire before the DOM exists in 2026.x
  api.onAppEvent("composer:inserted", () => {
    try {
      applyRandomPlaceholder();
    } catch (e) {
      // eslint-disable-next-line no-console
      console.warn("[rotating-composer-placeholder] failed:", e);
    }
  });

  // Keep as a fallback for certain flows
  api.onAppEvent("composer:reply-reloaded", () => {
    try {
      applyRandomPlaceholder();
    } catch (e) {
      // eslint-disable-next-line no-console
      console.warn("[rotating-composer-placeholder] failed:", e);
    }
  });
});
