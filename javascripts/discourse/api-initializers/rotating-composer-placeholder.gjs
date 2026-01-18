import { apiInitializer } from "discourse/lib/api";
import I18n from "I18n";

export default apiInitializer("1.0", (api) => {
  document.documentElement.setAttribute(
    "data-rotating-composer-placeholder-loaded",
    "1"
  );

  const FALLBACK = ["Write your reply…"];

  const KEYS = [
    "composer.reply_placeholder",
    "js.composer.reply_placeholder",
    "js.composer.reply_placeholder_rte",
    "js.composer.reply_placeholder_rte_no_images",
  ];

  let originals = null;
  let lastApplied = null;

  let richPinTimer = null;

  // Hold one chosen string per open composer session
  let currentText = null;

  // NEW (robust): prevent scheduleStart running twice for the same open flow
  let sessionActive = false;

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

  function localeRoot() {
    return I18n.translations[I18n.currentLocale()];
  }

  function getDeep(obj, path) {
    return path
      .split(".")
      .reduce((acc, part) => (acc ? acc[part] : undefined), obj);
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

  function setMarkdownPlaceholder(text) {
    const els = Array.from(
      document.querySelectorAll("textarea.d-editor-input")
    );
    if (!els.length) return false;
    els.forEach((el) => el.setAttribute("placeholder", text));
    return true;
  }

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

  function pinRichPlaceholder(text) {
    if (richPinTimer) {
      clearTimeout(richPinTimer);
      richPinTimer = null;
    }

    let tries = 0;
    const maxTries = 40;
    const delayMs = 80;

    const tick = () => {
      tries += 1;

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

    tick();
  }

  // Choose once per open
  function ensureCurrentText() {
    if (currentText) return currentText;
    const placeholders = getPlaceholdersFromSettings();
    currentText = pickRandom(placeholders);
    return currentText;
  }

  function applyPlaceholder(text) {
    applyI18nOverride(text);
    setMarkdownPlaceholder(text);
    pinRichPlaceholder(text);
  }

  // Called for “new session” moments
  function startNewPlaceholderSession() {
    currentText = null;
    const text = ensureCurrentText();
    applyPlaceholder(text);
  }

  // Called for “keep it pinned” moments (no reroll)
  function keepPinned() {
    const text = ensureCurrentText();
    applyPlaceholder(text);
  }

  // NEW (robust): only start once per session, even if open+opened both fire
  function scheduleStart() {
    if (sessionActive) return;
    sessionActive = true;

    setTimeout(startNewPlaceholderSession, 0);
    setTimeout(keepPinned, 150);
    setTimeout(keepPinned, 500);
  }

  function cleanup() {
    sessionActive = false;

    if (richPinTimer) {
      clearTimeout(richPinTimer);
      richPinTimer = null;
    }

    currentText = null;
    restoreI18n();
  }

  // Start a fresh rotation when composer opens
  api.onAppEvent("composer:open", scheduleStart);
  api.onAppEvent("composer:opened", scheduleStart);

  // Don’t reroll on reload; just keep the same pinned text
  api.onAppEvent("composer:reply-reloaded", () => {
    setTimeout(keepPinned, 0);
    setTimeout(keepPinned, 200);
  });

  // Cleanup when composer is dismissed/cancelled
  api.onAppEvent("composer:cancelled", cleanup);

  // Optional extra cleanup points:
  // api.onAppEvent("composer:created-post", cleanup);
  // api.onAppEvent("composer:edited-post", cleanup);

  api.onPageChange(() => cleanup());
});