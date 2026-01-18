import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.0", (api) => {
  const FALLBACK = ["Write your reply…"];

  function pickRandom(arr) {
    return arr[Math.floor(Math.random() * arr.length)];
  }

  function setComposerPlaceholder(text) {
    // wait a tick so the editor exists reliably
    requestAnimationFrame(() => {
      const el = document.querySelector(".d-editor-input");
      if (el) {
        el.setAttribute("placeholder", text);
      }
    });
  }

  function normalizePlaceholders(value) {
    // Case 1: already an array
    if (Array.isArray(value)) {
      return value.map((v) => String(v).trim()).filter(Boolean);
    }

    // Case 2: string (very common for theme list settings)
    if (typeof value === "string") {
      return value
        .split(/\r?\n|,/g)
        .map((s) => s.trim())
        .filter(Boolean);
    }

    // Anything else
    return [];
  }

  function getPlaceholdersFromSettings() {
    const raw = normalizePlaceholders(settings?.rotating_placeholders);
    return raw.length ? raw : FALLBACK;
  }

  function applyRandomPlaceholder() {
    const placeholders = getPlaceholdersFromSettings();
    setComposerPlaceholder(pickRandom(placeholders));
  }

  api.onAppEvent("composer:opened", () => {
    try {
      applyRandomPlaceholder();
    } catch (e) {
      // Never allow theme JS to break the composer
      // eslint-disable-next-line no-console
      console.warn(
        "[rotating-composer-placeholder] failed to set placeholder:",
        e
      );
    }
  });

  api.onAppEvent("composer:reply-reloaded", () => {
    try {
      applyRandomPlaceholder();
    } catch (e) {
      // eslint-disable-next-line no-console
      console.warn(
        "[rotating-composer-placeholder] failed to set placeholder:",
        e
      );
    }
  });
});
