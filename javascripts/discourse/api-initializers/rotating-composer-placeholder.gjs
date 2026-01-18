import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.0", (api) => {
  // PROOF this file is loaded (remove later)
  document.documentElement.setAttribute(
    "data-rotating-composer-placeholder-loaded",
    "1"
  );

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

  function setMarkdownPlaceholderOnce(text) {
    const el =
      document.querySelector(".d-editor textarea.d-editor-input") ||
      document.querySelector("textarea.d-editor-input");

    if (!el) return false;
    el.setAttribute("placeholder", text);
    return true;
  }

  function setProseMirrorRotatingPlaceholderOnce(text) {
    const pmEl = document.querySelector(
      ".d-editor .ProseMirror.d-editor-input[contenteditable='true']"
    );
    if (!pmEl) return false;

    const p = pmEl.querySelector("p");
    if (!p) return false;

    p.setAttribute("data-rotating-placeholder", text);
    pmEl.setAttribute("aria-label", text);

    // verify it actually stuck (helps avoid false positives while PM is still initializing)
    return p.getAttribute("data-rotating-placeholder") === text;
  }

  function applyMarkdownWithRetries(text) {
    let tries = 0;
    const maxTries = 30;
    const delayMs = 80;

    const tick = () => {
      tries += 1;
      if (setMarkdownPlaceholderOnce(text)) return;
      if (tries < maxTries) setTimeout(tick, delayMs);
    };

    tick();
    setTimeout(() => setMarkdownPlaceholderOnce(text), 150);
    setTimeout(() => setMarkdownPlaceholderOnce(text), 500);
    setTimeout(() => setMarkdownPlaceholderOnce(text), 1200);
  }

  function applyRichWithRetries(text) {
    let tries = 0;
    const maxTries = 60; // ~4.8s
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

    const hasMarkdown =
      !!document.querySelector(".d-editor textarea.d-editor-input") ||
      !!document.querySelector("textarea.d-editor-input");

    if (hasMarkdown) {
      applyMarkdownWithRetries(text);
    } else {
      applyRichWithRetries(text);
    }
  }

  function scheduleApply() {
    setTimeout(applyRandomPlaceholder, 0);
    setTimeout(applyRandomPlaceholder, 100);
    setTimeout(applyRandomPlaceholder, 400);
  }

  api.onAppEvent("composer:opened", scheduleApply);
  api.onAppEvent("composer:inserted", scheduleApply);
  api.onAppEvent("composer:reply-reloaded", scheduleApply);
  api.onPageChange(scheduleApply);
});
