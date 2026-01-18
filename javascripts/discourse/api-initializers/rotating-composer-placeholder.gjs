import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.0", (api) => {
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

  // ---------- Markdown ----------
  function setMarkdownPlaceholder(text) {
    const els = Array.from(document.querySelectorAll("textarea.d-editor-input"));
    if (!els.length) return false;
    els.forEach((el) => el.setAttribute("placeholder", text));
    return true;
  }

  // ---------- Rich (ProseMirror) ----------
  function proseMirrorIsEmpty(pmEl) {
    const txt = (pmEl.textContent || "").replace(/\u200B/g, "").trim();
    return txt.length === 0;
  }

  function setProseMirrorPlaceholder(text) {
    const pmEl = document.querySelector(".ProseMirror.d-editor-input");
    if (!pmEl) return false;

    // Only touch it while empty to avoid fighting editor updates
    if (!proseMirrorIsEmpty(pmEl)) return true;

    const p = pmEl.querySelector("p[data-placeholder]") || pmEl.querySelector("p");
    if (!p) return false;

    // Overwrite the actual attribute Discourse uses
    p.setAttribute("data-placeholder", text);
    pmEl.setAttribute("aria-label", text);

    return p.getAttribute("data-placeholder") === text;
  }

  // Run a bounded set of attempts (no loops, no observers)
  function applyOncePerOpen(text) {
    // always do markdown; harmless if hidden
    setMarkdownPlaceholder(text);

    // do rich: a few delayed attempts to catch late mount, then stop
    const delays = [0, 80, 180, 350, 700, 1200, 2000];
    delays.forEach((d) => setTimeout(() => setProseMirrorPlaceholder(text), d));
  }

  function applyRandomPlaceholder() {
    const placeholders = getPlaceholdersFromSettings();
    const text = pickRandom(placeholders);
    applyOncePerOpen(text);
  }

  api.onAppEvent("composer:opened", applyRandomPlaceholder);
  api.onAppEvent("composer:inserted", applyRandomPlaceholder);
  api.onAppEvent("composer:reply-reloaded", applyRandomPlaceholder);
  api.onPageChange(applyRandomPlaceholder);
});
