import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.0", (api) => {
  document.documentElement.setAttribute(
    "data-rotating-composer-placeholder-loaded",
    "1"
  );

  const FALLBACK = ["Write your reply…"];

  let pmObserver = null;
  let pinnedText = null;

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

  // ---------- Markdown ----------
  function setMarkdownPlaceholder(text) {
    const els = Array.from(document.querySelectorAll("textarea.d-editor-input"));
    if (!els.length) return false;
    els.forEach((el) => el.setAttribute("placeholder", text));
    return true;
  }

  // ---------- Rich (ProseMirror) ----------
  function findProseMirrorRoot() {
    return document.querySelector(".ProseMirror.d-editor-input");
  }

  function applyProseMirrorPlaceholder(text) {
    const pm = findProseMirrorRoot();
    if (!pm) return false;

    const p = pm.querySelector("p[data-placeholder]") || pm.querySelector("p");
    if (!p) return false;

    // overwrite the actual attribute Discourse uses for the watermark
    p.setAttribute("data-placeholder", text);
    pm.setAttribute("aria-label", text);

    return p.getAttribute("data-placeholder") === text;
  }

  function cleanupObserver() {
    if (pmObserver) {
      pmObserver.disconnect();
      pmObserver = null;
    }
    pinnedText = null;
  }

  function pinProseMirrorPlaceholder(text) {
    pinnedText = text;

    const pm = findProseMirrorRoot();
    if (!pm) return;

    // Apply immediately + a few delayed passes during mount
    applyProseMirrorPlaceholder(text);
    setTimeout(() => applyProseMirrorPlaceholder(text), 50);
    setTimeout(() => applyProseMirrorPlaceholder(text), 150);
    setTimeout(() => applyProseMirrorPlaceholder(text), 500);
    setTimeout(() => applyProseMirrorPlaceholder(text), 1200);

    // Observe only the ProseMirror root while composer is open
    cleanupObserver();
    pmObserver = new MutationObserver(() => {
      if (pinnedText) applyProseMirrorPlaceholder(pinnedText);
    });

    pmObserver.observe(pm, {
      subtree: true,
      childList: true,
      attributes: true,
      attributeFilter: ["data-placeholder", "class"],
    });
  }

  function applyRandomPlaceholder() {
    const placeholders = getPlaceholdersFromSettings();
    const text = pickRandom(placeholders);

    // markdown (works already)
    setMarkdownPlaceholder(text);

    // rich (pin it)
    pinProseMirrorPlaceholder(text);
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

  // Cleanup (event may or may not exist; safe optional chaining)
  api.onAppEvent?.("composer:closed", cleanupObserver);
});
