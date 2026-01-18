import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.0", (api) => {
  const FALLBACK = ["Write your reply…"];

  function pickRandom(arr) {
    return arr[Math.floor(Math.random() * arr.length)];
  }

  function setComposerPlaceholderWithRetries(text) {
    let tries = 0;
    const maxTries = 12;
    const delayMs = 50;

    const attempt = () => {
      tries += 1;

      const el = document.querySelector("textarea.d-editor-input");
      if (el) {
        el.setAttribute("placeholder", text);
        return;
      }

      if (tries < maxTries) {
        setTimeout(attempt, delayMs);
      }
    };

    // Try immediately and then a few times while the composer mounts
    attempt();

    // Try again a little later in case Ember overwrites it after render
    setTimeout(() => {
      const el = document.querySelector("textarea.d-editor-input");
      if (el) el.setAttribute("placeholder", text);
    }, 250);

    setTimeout(() => {
      const el = document.querySelector("textarea.d-editor-input");
      if (el) el.setAttribute("placeholder", text);
    }, 800);
  }

  function normalizePlaceholders(value) {
    if (Array.isArray(value)) {
      return value.map((v) => String(v).trim()).filter(Boolean);
    }

    if (typeof value === "string") {
      return value
        .split(/\r?\n|,|\|/g) // include pipe separator
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
    console.log("[rotating-composer-placeholder] composer opened, settings:", settings?.rotating_placeholders);
  }

  api.onAppEvent("composer:opened", () => {
    try {
      applyRandomPlaceholder();
    } catch (e) {
      // eslint-disable-next-line no-console
      console.warn("[rotating-composer-placeholder] failed:", e);
    }
  });

  api.onAppEvent("composer:reply-reloaded", () => {
    try {
      applyRandomPlaceholder();
    } catch (e) {
      // eslint-disable-next-line no-console
      console.warn("[rotating-composer-placeholder] failed:", e);
    }
  });
});

