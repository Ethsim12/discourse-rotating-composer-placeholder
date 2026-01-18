import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.0", (api) => {
  const FALLBACK = ["Write your reply…"];

  function pickRandom(arr) {
    return arr[Math.floor(Math.random() * arr.length)];
  }

  function normalizePlaceholders(value) {
    if (Array.isArray(value)) {
      return value.map((v) => String(v).trim()).filter(Boolean);
    }

    if (typeof value === "string") {
      return value
        .split(/\r?\n|,|\|/g)
        .map((s) => s.trim())
        .filter(Boolean);
    }

    return [];
  }

  function getPlaceholdersFromSettings() {
    const raw = normalizePlaceholders(settings?.rotating_placeholders);
    return raw.length ? raw : FALLBACK;
  }

  function setMarkdownPlaceholder(text) {
    const el = document.querySelector(".d-editor textarea.d-editor-input");
    if (!el) return false;
    el.setAttribute("placeholder", text);
    return true;
  }

  function setProseMirrorRotatingPlaceholder(text) {
    const pmEl = document.querySelector(
      ".d-editor .ProseMirror.d-editor-input[contenteditable='true']"
    );
    const p = pmEl?.querySelector("p");
    if (!p) return false;

    // Leave Discourse's data-placeholder alone (it will keep resetting it),
    // but set our own attribute that CSS will display.
    p.setAttribute("data-rotating-placeholder", text);

    // Optional accessibility
    pmEl.setAttribute("aria-label", text);

    return true;
  }

  function applyPlaceholderOnce(text) {
    if (setMarkdownPlaceholder(text)) return true;
    return setProseMirrorRotatingPlaceholder(text);
  }

  function applyWithRetries(text) {
    // No observers. Just a few delayed passes for mount timing.
    applyPlaceholderOnce(text);
    setTimeout(() => applyPlaceholderOnce(text), 80);
    setTimeout(() => applyPlaceholderOnce(text), 200);
    setTimeout(() => applyPlaceholderOnce(text), 500);
    setTimeout(() => applyPlaceholderOnce(text), 1000);
    setTimeout(() => applyPlaceholderOnce(text), 2000);
  }

  function applyRandomPlaceholder() {
    const placeholders = getPlaceholdersFromSettings();
    applyWithRetries(pickRandom(placeholders));
  }

  api.onAppEvent("composer:inserted", () => {
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
