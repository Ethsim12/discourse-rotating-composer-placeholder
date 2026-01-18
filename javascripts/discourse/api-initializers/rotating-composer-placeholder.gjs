import { apiInitializer } from "discourse/lib/api";
import I18n from "I18n";

export default apiInitializer("1.0", (api) => {
  document.documentElement.setAttribute(
    "data-rotating-composer-placeholder-loaded",
    "1"
  );

  const FALLBACK = ["Write your reply…"];

  let originalPlaceholder = null;
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

  // Markdown still set directly (works)
  function setMarkdownPlaceholder(text) {
    const els = Array.from(document.querySelectorAll("textarea.d-editor-input"));
    if (!els.length) return false;
    els.forEach((el) => el.setAttribute("placeholder", text));
    return true;
  }

  // ---- Rich editor uses an i18n key for its placeholder text ----
  // We override it temporarily.
  //
  // NOTE: key name can vary. We try a few known candidates.
  const PLACEHOLDER_KEYS = [
    "composer.placeholder", // common pattern
    "composer.reply_placeholder", // classic js.composer.reply_placeholder equivalent
    "js.composer.reply_placeholder", // site text key you referenced earlier
    "composer.composer_placeholder", // fallback candidate
  ];

  function findFirstExistingKey() {
    for (const k of PLACEHOLDER_KEYS) {
      const v = I18n.t(k, { defaultValue: null });
      if (v && typeof v === "string" && v.length) return k;
    }
    return null;
  }

  const placeholderKey = findFirstExistingKey();

  function applyRichPlaceholder(text) {
    if (!placeholderKey) return false;

    if (originalPlaceholder === null) {
      originalPlaceholder = I18n.t(placeholderKey);
    }

    // Avoid repeated writes
    if (lastApplied === text) return true;

    // Override translation lookup
    I18n.translations[I18n.currentLocale()][placeholderKey] = text;
    lastApplied = text;

    return true;
  }

  function restoreRichPlaceholder() {
    if (!placeholderKey) return;

    if (originalPlaceholder !== null) {
      I18n.translations[I18n.currentLocale()][placeholderKey] = originalPlaceholder;
    }
    lastApplied = null;
    originalPlaceholder = null;
  }

  function applyRandomPlaceholder() {
    const placeholders = getPlaceholdersFromSettings();
    const text = pickRandom(placeholders);

    // markdown
    setMarkdownPlaceholder(text);

    // rich (via i18n)
    applyRichPlaceholder(text);
  }

  function scheduleApply() {
    setTimeout(applyRandomPlaceholder, 0);
    setTimeout(applyRandomPlaceholder, 150);
    setTimeout(applyRandomPlaceholder, 500);
  }

  api.onAppEvent("composer:opened", scheduleApply);
  api.onAppEvent("composer:inserted", scheduleApply);
  api.onAppEvent("composer:reply-reloaded", scheduleApply);

  api.onAppEvent?.("composer:closed", () => {
    restoreRichPlaceholder();
  });

  api.onPageChange(() => {
    restoreRichPlaceholder();
  });
});
