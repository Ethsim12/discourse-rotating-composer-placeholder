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

    // Title input (not what we want for reply watermark)
    // root.querySelector("#reply-title") exists, but skip it.

    // Rich editor content area (contenteditable)
    const rich =
      root.querySelector(".d-editor-input[contenteditable='true']") ||
      root.querySelector(".d-editor-container [contenteditable='true']") ||
      root.querySelector(".composer-fields [contenteditable='true']");

    if (rich) return { kind: "rich", el: rich, root };

    // Legacy markdown textarea fallback (older setups)
    const textarea = root.querySelector("textarea.d-editor-input");
    if (textarea) return { kind: "textarea", el: textarea, root };

    return null;
  }

  function setComposerPlaceholder(text) {
    const found = findEditorElement();
    if (!found) return false;

    if (found.kind === "textarea") {
      found.el.setAttribute("placeholder", text);
      return true;
    }

    // Rich editor: set placeholder hooks used by CSS/ARIA
    found.el.setAttribute("data-placeholder", text);
    found.el.setAttribute("aria-label", text);

    // Also set on a stable wrapper that often drives ::before placeholder CSS
    const wrapper =
      found.root.querySelector(".d-editor-container") ||
      found.root.querySelector(".d-editor-textarea-column") ||
      found.root;

    wrapper.setAttribute("data-placeholder", text);

    // If a placeholder node exists, update it too
    const placeholderNode =
      found.root.querySelector(".d-editor-placeholder") ||
      found.root.querySelector(".composer-placeholder");

    if (placeholderNode) placeholderNode.textContent = text;

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
