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
    if (!pmEl) return false;

    // ProseMirror may not have created the first paragraph yet
    const p = pmEl.querySelector("p");
    if (!p) return false;

    p.setAttribute("data-rotating-placeholder", text);
    pmEl.setAttribute("aria-label", text);
    return true;
  }


  function applyPlaceholderOnce(text) {
    if (setMarkdownPlaceholder(text)) return true;
    return setProseMirrorRotatingPlaceholder(text);
  }

  function applyRichWithRetries(text) {
    let tries = 0;
    const maxTries = 30; // ~2.4s at 80ms
    const delayMs = 80;

    const tick = () => {
      tries += 1;

      if (setProseMirrorRotatingPlaceholder(text)) return;
      if (tries < maxTries) setTimeout(tick, delayMs);
    };

    tick();
  }


  function applyWithRetries(text) {
    // markdown attempt
    if (setMarkdownPlaceholder(text)) return;

    // rich attempt (wait until <p> exists)
    applyRichWithRetries(text);
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
