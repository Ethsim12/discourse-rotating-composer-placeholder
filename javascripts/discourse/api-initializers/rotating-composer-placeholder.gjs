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

  function getVisibleMarkdownTextarea() {
    const candidates = Array.from(
      document.querySelectorAll("textarea.d-editor-input")
    );
    // Prefer one that is actually visible (not display:none, not hidden in another editor)
    return (
      candidates.find((t) => t.offsetParent !== null) ||
      candidates[0] ||
      null
    );
  }

  function getVisibleProseMirror() {
    const candidates = Array.from(
      document.querySelectorAll(
        ".ProseMirror.d-editor-input[contenteditable='true']"
      )
    );
    return (
      candidates.find((pm) => pm.offsetParent !== null) ||
      candidates[0] ||
      null
    );
  }

  function setMarkdownPlaceholderOnce(text) {
    const el = getVisibleMarkdownTextarea();
    if (!el) return false;

    el.setAttribute("placeholder", text);
    return true;
  }

  function setProseMirrorRotatingPlaceholderOnce(text) {
    const pmEl = getVisibleProseMirror();
    if (!pmEl) return false;

    const p = pmEl.querySelector("p");
    if (!p) return false;

    p.setAttribute("data-rotating-placeholder", text);
    pmEl.setAttribute("aria-label", text);

    // verify it stuck
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

    // ✅ Prefer ProseMirror if it exists (even if a hidden textarea also exists)
    const hasPM = !!getVisibleProseMirror();

    if (hasPM) {
      applyRichWithRetries(text);
    } else {
      applyMarkdownWithRetries(text);
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
