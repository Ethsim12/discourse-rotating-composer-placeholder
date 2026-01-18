import { apiInitializer } from "discourse/lib/api";
import I18n from "I18n";

export default apiInitializer("1.0", (api) => {
  // PROOF this file is loaded (remove later)
  document.documentElement.setAttribute(
    "data-rotating-composer-placeholder-loaded",
    "1"
  );

  const FALLBACK = ["Write your reply…"];

  // These are the keys you proved exist on your build
  const KEYS = ["composer.reply_placeholder", "js.composer.reply_placeholder"];

  // originals = Map key -> original string
  let originals = null;
  let lastApplied = null;

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

  // ---- helpers for nested I18n keys ----
  function localeRoot() {
    return I18n.translations[I18n.currentLocale()];
  }

  function getDeep(obj, path) {
    return path.split(".").reduce((acc, part) => (acc ? acc[part] : undefined), obj);
  }

  function setDeep(obj, path, value) {
    const parts = path.split(".");
    let cur = obj;

    for (let i = 0; i < parts.length - 1; i++) {
      const p = parts[i];
      if (typeof cur[p] !== "object" || cur[p] === null) cur[p] = {};
      cur = cur[p];
    }

    cur[parts[parts.length - 1]] = value;
  }

  // ---- Markdown (still direct) ----
  function setMarkdownPlaceholder(text) {
    const els = Array.from(document.querySelectorAll("textarea.d-editor-input"));
    if (!els.length) return false;
    els.forEach((el) => el.setAttribute("placeholder", text));
    return true;
  }

  function captureOriginalsOnce() {
    if (originals) return;

    originals = {};
    const root = localeRoot();

    KEYS.forEach((k) => {
      const v = getDeep(root, k);
      if (typeof v === "string") originals[k] = v;
    });
  }

  function applyRichPlaceholder(text) {
    captureOriginalsOnce();
    if (!originals || lastApplied === text) return;

    const root = localeRoot();

    KEYS.forEach((k) => {
      if (k in originals) {
        setDeep(root, k, text);
      }
    });

    lastApplied = text;
  }

  function restoreRichPlaceholder() {
    if (!originals) return;

    const root = localeRoot();
    Object.keys(originals).forEach((k) => setDeep(root, k, originals[k]));

    originals = null;
    lastApplied = null;
  }

  function applyRandomPlaceholder() {
    const placeholders = getPlaceholdersFromSettings();
    const text = pickRandom(placeholders);

    // markdown (cheap)
    setMarkdownPlaceholder(text);

    // rich (update translation source)
    applyRichPlaceholder(text);
  }

  function scheduleApply() {
    // a few bounded passes to catch composer mount/toggle
    setTimeout(applyRandomPlaceholder, 0);
    setTimeout(applyRandomPlaceholder, 150);
    setTimeout(applyRandomPlaceholder, 500);
    setTimeout(applyRandomPlaceholder, 1200);
  }

  api.onAppEvent("composer:opened", scheduleApply);
  api.onAppEvent("composer:inserted", scheduleApply);
  api.onAppEvent("composer:reply-reloaded", scheduleApply);

  api.onAppEvent?.("composer:closed", restoreRichPlaceholder);
  api.onPageChange(() => restoreRichPlaceholder());
});
