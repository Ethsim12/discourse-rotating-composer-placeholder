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

  // ---- Rich editor DOM sync (ONE-OFF, bounded) ----
  function syncMountedRichPlaceholder(text) {
    const p = document.querySelector(
      ".d-editor .ProseMirror.d-editor-input p[data-placeholder]"
    );
    if (p) {
      p.setAttribute("data-placeholder", text);
    }

    const pm = document.querySelector(".d-editor .ProseMirror.d-editor-input");
    if (pm) {
      pm.setAttribute("aria-label", text);
    }

    return !!p;
  }

  function applyRandomPlaceholder() {
    const placeholders = getPlaceholdersFromSettings();
    const text = pickRandom(placeholders);

    // 1) Update sources (future mounts)
    applyI18nOverride(text);

    // 2) Markdown (current DOM)
    setMarkdownPlaceholder(text);

    // 3) Rich (current DOM) — do a couple of bounded passes
    // so we catch the moment ProseMirror inserts the <p data-placeholder>
    const delays = [0, 120, 350, 800];
    delays.forEach((d) => setTimeout(() => syncMountedRichPlaceholder(text), d));
  }

  function scheduleApply() {
    setTimeout(applyRandomPlaceholder, 0);
    setTimeout(applyRandomPlaceholder, 150);
    setTimeout(applyRandomPlaceholder, 500);
  }

  api.onAppEvent("composer:opened", scheduleApply);
  api.onAppEvent("composer:inserted", scheduleApply);
  api.onAppEvent("composer:reply-reloaded", scheduleApply);

  api.onAppEvent?.("composer:closed", restoreI18n);
  api.onPageChange(() => restoreI18n());
});
