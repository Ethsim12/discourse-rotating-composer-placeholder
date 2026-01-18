import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.0", (api) => {
  const FALLBACK = ["Write your reply…"];

  function pickRandom(arr) {
    return arr[Math.floor(Math.random() * arr.length)];
  }

  // Find the editor input once the composer is actually in the DOM
  function findEditorElement() {
    // Legacy markdown editor
    const textarea =
      document.querySelector("textarea.d-editor-input") ||
      document.querySelector("textarea");

    if (textarea) return textarea;

    // Some builds/editors may not use textarea; fall back to any editor-like input
    return (
      document.querySelector(".d-editor-input") ||
      document.querySelector("[contenteditable='true']") ||
      null
    );
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
        `[rotating-composer-placeholder] try ${tries}`,
        { ok, hasComposer: !!document.querySelector(".composer") }
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
