import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.0", (api) => {
  const FALLBACK = ["Write your reply…"];

  function pickRandom(arr) {
    return arr[Math.floor(Math.random() * arr.length)];
  }

  // Find the editor input once the composer is actually in the DOM
  function findEditorElement() {
    const composer =
      document.querySelector(".composer") ||
      document.querySelector(".composer-container") ||
      document.querySelector(".d-editor");

    if (!composer) return null;

    // Legacy markdown textarea
    const textarea = composer.querySelector("textarea.d-editor-input");
    if (textarea) return textarea;

    // Some variants still use this class (not necessarily textarea)
    const dEditorInput = composer.querySelector(".d-editor-input");
    if (dEditorInput) return dEditorInput;

    // Contenteditable editors
    const ce = composer.querySelector("[contenteditable='true']");
    if (ce) return ce;

    // Last resort: any textarea within composer
    return composer.querySelector("textarea") || null;
  }


  function setComposerPlaceholder(text) {
    const el = findEditorElement();
    if (!el) return false;

    // textarea
    if (el.tagName === "TEXTAREA") {
      el.setAttribute("placeholder", text);
      return true;
    }

    // contenteditable / other editor
    el.setAttribute("data-placeholder", text);
    el.setAttribute("aria-label", text);
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
