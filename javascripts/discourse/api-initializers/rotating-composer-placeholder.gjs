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

  function getProseMirrorEl() {
    return document.querySelector(
      ".d-editor .ProseMirror.d-editor-input[contenteditable='true']"
    );
  }

  function setProseMirrorPlaceholder(text) {
    const pmEl = getProseMirrorEl();
    const p = pmEl?.querySelector("p");
    if (!p) return false;

    // Visible watermark source in your DOM
    p.setAttribute("data-placeholder", text);

    // Optional accessibility
    pmEl.setAttribute("aria-label", text);

    return true;
  }

  function applyRichPlaceholderSafely(text) {
    // A few delayed passes to beat editor init (no observers, no intervals)
    setProseMirrorPlaceholder(text);
    setTimeout(() => setProseMirrorPlaceholder(text), 50);
    setTimeout(() => setProseMirrorPlaceholder(text), 150);
    setTimeout(() => setProseMirrorPlaceholder(text), 400);
    setTimeout(() => setProseMirrorPlaceholder(text), 900);
    setTimeout(() => setProseMirrorPlaceholder(text), 1600);
  }

  function setMarkdownPlaceholder(text) {
    const el = document.querySelector(".d-editor textarea.d-editor-input");
    if (!el) return false;

    el.setAttribute("placeholder", text);
    return true;
  }

  function applyRandomPlaceholder() {
    const placeholders = getPlaceholdersFromSettings();
    const text = pickRandom(placeholders);

    // Try markdown first
    if (setMarkdownPlaceholder(text)) return;

    // Otherwise rich editor
    applyRichPlaceholderSafely(text);
  }

  // Rich editor can mount shortly after inserted; retry lightly.
  function applyWithRetries() {
    let tries = 0;
    const maxTries = 10;

    const tick = () => {
      tries += 1;
      applyRandomPlaceholder();

      const hasMarkdown = !!document.querySelector(
        ".d-editor textarea.d-editor-input"
      );
      const hasPM = !!getProseMirrorEl();

      if ((hasMarkdown || hasPM) || tries >= maxTries) return;
      setTimeout(tick, 80);
    };

    tick();
  }

  api.onAppEvent("composer:inserted", () => {
    try {
      applyWithRetries();
    } catch (e) {
      // eslint-disable-next-line no-console
      console.warn("[rotating-composer-placeholder] failed:", e);
    }
  });

  api.onAppEvent("composer:reply-reloaded", () => {
    try {
      applyWithRetries();
    } catch (e) {
      // eslint-disable-next-line no-console
      console.warn("[rotating-composer-placeholder] failed:", e);
    }
  });
});
