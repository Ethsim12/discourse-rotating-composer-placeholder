import { apiInitializer } from "discourse/lib/api";
import I18n from "I18n";

export default apiInitializer("1.0", (api) => {
  // PROOF this file is loaded (remove later)
  document.documentElement.setAttribute(
    "data-rotating-composer-placeholder-loaded",
    "1"
  );

  const FALLBACK = ["Write your reply…"];
  const KEYS = ["composer.reply_placeholder", "js.composer.reply_placeholder"];

  let originals = null; // { key: originalString }
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

  // ---- Markdown (textarea) ----
  function setMarkdownPlaceholder(text) {
    const els = Array.from(document.querySelectorAll("textarea.d-editor-input"));
    if (!els.length) return false;
    els.forEach((el) => el.setAttribute("placeholder", text));
    return true;
  }

  // ---- Rich editor (i18n-driven placeholder) ----
  function currentLocaleTranslations() {
    // In Discourse, this is the object backing I18n.t() for the current locale
    return I18n.translations[I18n.currentLocale()];
  }

  function captureOriginalsOnce() {
    if (originals) return;

    originals = {};
    KEYS.forEach((k) => {
      const v = I18n.t(k, { defaultValue: null });
      if (typeof v === "string") originals[k] = v;
    });
  }

  function applyRichPlaceholder(text) {
    captureOriginalsOnce();
    if (lastApplied === text) return;

    const t = currentLocaleTranslations();

    // Update both keys (they’re currently identical on your build)
    KEYS.forEach((k) => {
      if (k in originals) {
        t[k] = text;
      }
    });

    lastApplied = text;
  }

  function restoreRichPlaceholder() {
    if (!originals) return;

    const t = currentLocaleTranslations();
    Object.keys(originals).forEach((k) => {
      t[k] = originals[k];
    });

    lastApplied = null;
    originals = null;
  }

  function applyRandomPlaceholder() {
    const placeholders = getPlaceholdersFromSettings();
    const text = pickRandom(placeholders);

    // markdown (cheap, harmless even if hidden)
    setMarkdownPlaceholder(text);

    // rich (this is what the ProseMirror placeholder is actually reading)
    applyRichPlaceholder(text);
  }

  // In 2026.x the composer DOM/instance can come in after the event, so do a few bounded passes
  function scheduleApply() {
    setTimeout(applyRandomPlaceholder, 0);
    setTimeout(applyRandomPlaceholder, 150);
    setTimeout(applyRandomPlaceholder, 500);
    setTimeout(applyRandomPlaceholder, 1200);
  }

  api.onAppEvent("composer:opened", scheduleApply);
  api.onAppEvent("composer:inserted", scheduleApply);
  api.onAppEvent("composer:reply-reloaded", scheduleApply);

  // cleanup
  api.onAppEvent?.("composer:closed", restoreRichPlaceholder);
  api.onPageChange(() => restoreRichPlaceholder());
});
