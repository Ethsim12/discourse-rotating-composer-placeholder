import { apiInitializer } from "discourse/lib/api";
import I18n from "I18n";

export default apiInitializer("1.0", (api) => {
  document.documentElement.setAttribute(
    "data-rotating-composer-placeholder-loaded",
    "1"
  );

  const FALLBACK = ["Write your reply…"];

  const KEYS = [
    // Markdown composer
    "composer.reply_placeholder",
    "js.composer.reply_placeholder",

    // Rich text editor (RTE)
    "js.composer.reply_placeholder_rte",
    "js.composer.reply_placeholder_rte_no_images",
  ];

  let originals = null;
  let lastApplied = null;

  // Track one in-flight pin job so we don't stack timers on repeated events
  let richPinTimer = null;

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

  // ---- nested i18n helpers ----
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

  function captureOriginalsOnce() {
    if (originals) return;

    originals = {};
    const root = localeRoot();

    KEYS.forEach((k) => {
      const v = getDeep(root, k);
      if (typeof v === "string") originals[k] = v;
    });
  }

  function applyI18nOverride(text) {
    captureOriginalsOnce();
    if (!originals) return;
    if (lastApplied === text) return;

    const root = localeRoot();
    Object.keys(originals).forEach((k) => setDeep(root, k, text));

    lastApplied = text;
  }

  function restoreI18n() {
    if (!originals) return;

    const root = localeRoot();
    Object.keys(originals).forEach((k) => setDeep(root, k, originals[k]));

    originals = null;
    lastApplied = null;
  }

  // ---- Markdown textarea ----
  function setMarkdownPlaceholder(text) {
    const els = Array.from(document.querySelectorAll("textarea.d-editor-input"));
    if (!els.length) return false;
    els.forEach((el) => el.setAttribute("placeholder", text));
    return true;
  }

  // ---- Rich editor pinning ----
  function getRichPlaceholderNode() {
    return document.querySelector(
      ".d-editor .ProseMirror.d-editor-input p[data-placeholder]"
    );
  }

  function setRichPlaceholderNow(text) {
    const p = getRichPlaceholderNode();
    if (!p) return false;

    p.setAttribute("data-placeholder", text);

    const pm = document.querySelector(".d-editor .ProseMirror.d-editor-input");
    if (pm) pm.setAttribute("aria-label", text);

    return p.getAttribute("data-placeholder") === text;
  }

  // Bounded “late win” to beat ProseMirror/Discourse overwrites.
  // Runs at most ~3s, stops immediately once it sticks.
  function pinRichPlaceholder(text) {
    if (richPinTimer) {
      clearTimeout(richPinTimer);
      richPinTimer = null;
    }

    let tries = 0;
    const maxTries = 40; // 40 * 80ms ~= 3.2s
    const delayMs = 80;

    const tick = () => {
      tries += 1;

      // If the node doesn't exist yet, or Discourse overwrote it, keep trying
      const ok = setRichPlaceholderNow(text);
      if (ok) {
        richPinTimer = null;
        return;
      }

      if (tries < maxTries) {
        richPinTimer = setTimeout(tick, delayMs);
      } else {
        richPinTimer = null;
      }
    };

    // Start immediately
    tick();
  }

  function applyRandomPlaceholder() {
    const placeholders = getPlaceholdersFromSettings();
    const text = pickRandom(placeholders);

    // 1) Override sources for any future mount
    applyI18nOverride(text);

    // 2) Markdown (works already)
    setMarkdownPlaceholder(text);

    // 3) Rich: keep winning for a short bounded time
    pinRichPlaceholder(text);
  }

  function scheduleApply() {
    setTimeout(applyRandomPlaceholder, 0);
    setTimeout(applyRandomPlaceholder, 150);
    setTimeout(applyRandomPlaceholder, 500);
  }

  function cleanup() {
    if (richPinTimer) {
      clearTimeout(richPinTimer);
      richPinTimer = null;
    }
    restoreI18n();
  }

  api.onAppEvent("composer:opened", scheduleApply);
  api.onAppEvent("composer:inserted", scheduleApply);
  api.onAppEvent("composer:reply-reloaded", scheduleApply);

  api.onAppEvent?.("composer:closed", cleanup);
  api.onPageChange(() => cleanup());
});

