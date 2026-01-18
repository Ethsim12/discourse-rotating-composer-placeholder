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

  // ---- Markdown (legacy textarea) ----
  function setMarkdownPlaceholderOnce(text) {
    const els = Array.from(document.querySelectorAll("textarea.d-editor-input"));
    if (!els.length) return false;

    els.forEach((el) => el.setAttribute("placeholder", text));
    return true;
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

  // ---- Rich editor (ProseMirror) ----
  function setProseMirrorRotatingPlaceholderOnce(text) {
    // Don’t over-specify selectors; match what you actually see in the DOM
    const pmRoots = Array.from(document.querySelectorAll(".ProseMirror.d-editor-input"));
    if (!pmRoots.length) return false;

    let changed = false;

    pmRoots.forEach((pmEl) => {
      const p = pmEl.querySelector("p");
      if (!p) return;

      p.setAttribute("data-rotating-placeholder", text);
      pmEl.setAttribute("aria-label", text);

      if (p.getAttribute("data-rotating-placeholder") === text) {
        changed = true;
      }
    });

    return changed;
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

    // Apply to BOTH – avoids unreliable “which editor is active” checks
    applyMarkdownWithRetries(text);
    applyRichWithRetries(text);
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
