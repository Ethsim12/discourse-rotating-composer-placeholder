import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.0", (api) => {
  document.documentElement.setAttribute("data-rotating-composer-placeholder-loaded", "1");
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

  // ---- Markdown ----
  function setMarkdownPlaceholderOnce(text) {
    const el =
      document.querySelector(".d-editor textarea.d-editor-input") ||
      document.querySelector("textarea.d-editor-input");

    if (!el) return false;

    el.setAttribute("placeholder", text);
    return true;
  }

  function applyMarkdownWithRetries(text) {
    let tries = 0;
    const maxTries = 30; // ~2.4s
    const delayMs = 80;

    const tick = () => {
      tries += 1;
      if (setMarkdownPlaceholderOnce(text)) return;
      if (tries < maxTries) setTimeout(tick, delayMs);
    };

    // also do a few “late wins” in case Discourse overwrites placeholder after mount
    tick();
    setTimeout(() => setMarkdownPlaceholderOnce(text), 150);
    setTimeout(() => setMarkdownPlaceholderOnce(text), 500);
    setTimeout(() => setMarkdownPlaceholderOnce(text), 1200);
  }

  // ---- Rich (ProseMirror) ----
  function setProseMirrorRotatingPlaceholderOnce(text) {
    const pmEl = document.querySelector(
      ".d-editor .ProseMirror.d-editor-input[contenteditable='true']"
    );
    if (!pmEl) return false;

    const p = pmEl.querySelector("p");
    if (!p) return false;

    // we render this via CSS
    p.setAttribute("data-rotating-placeholder", text);
    pmEl.setAttribute("aria-label", text);
    return true;
  }

  function applyRichWithRetries(text) {
    let tries = 0;
    const maxTries = 30; // ~2.4s
    const delayMs = 80;

    const tick = () => {
      tries += 1;
      if (setProseMirrorRotatingPlaceholderOnce(text)) return;
      if (tries < maxTries) setTimeout(tick, delayMs);
    };

    tick();
    setTimeout(() => setProseMirrorRotatingPlaceholderOnce(text), 150);
    setTimeout(() => setProseMirrorRotatingPlaceholderOnce(text), 500);
    setTimeout(() => setProseMirrorRotatingPlaceholderOnce(text), 1200);
  }

  function applyRandomPlaceholder() {
    const placeholders = getPlaceholdersFromSettings();
    const text = pickRandom(placeholders);

    // If markdown exists, keep “winning” after Discourse overwrites
    const hasMarkdown =
      !!document.querySelector(".d-editor textarea.d-editor-input") ||
      !!document.querySelector("textarea.d-editor-input");

    if (hasMarkdown) {
      applyMarkdownWithRetries(text);
      return;
    }

    // otherwise try rich
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
