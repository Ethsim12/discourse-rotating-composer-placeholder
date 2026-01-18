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

  // Markdown
  function setMarkdownPlaceholderOnce(text) {
    const els = Array.from(document.querySelectorAll("textarea.d-editor-input"));
    if (!els.length) return false;
    els.forEach((el) => el.setAttribute("placeholder", text));
    return true;
  }

  function applyMarkdownWithRetries(text) {
    let tries = 0;
    const maxTries = 20;
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

  // Rich (ProseMirror) — write ONLY to the root, not <p>
  function setProseMirrorRootPlaceholderOnce(text) {
    const pmRoots = Array.from(
      document.querySelectorAll(".ProseMirror.d-editor-input")
    );
    if (!pmRoots.length) return false;

    pmRoots.forEach((pmEl) => {
      pmEl.setAttribute("data-rcp-root", "1");
      pmEl.setAttribute("data-rotating-placeholder", text); // <-- on root
      pmEl.setAttribute("aria-label", text);
    });

    // verify at least one stuck
    return pmRoots.some(
      (pmEl) => pmEl.getAttribute("data-rotating-placeholder") === text
    );
  }

  function applyRichWithRetries(text) {
    let tries = 0;
    const maxTries = 60;
    const delayMs = 80;

    const tick = () => {
      tries += 1;
      if (setProseMirrorRootPlaceholderOnce(text)) return;
      if (tries < maxTries) setTimeout(tick, delayMs);
    };

    tick();
    setTimeout(() => setProseMirrorRootPlaceholderOnce(text), 150);
    setTimeout(() => setProseMirrorRootPlaceholderOnce(text), 500);
    setTimeout(() => setProseMirrorRootPlaceholderOnce(text), 1200);
    setTimeout(() => setProseMirrorRootPlaceholderOnce(text), 2500);
  }

  function applyRandomPlaceholder() {
    const placeholders = getPlaceholdersFromSettings();
    const text = pickRandom(placeholders);

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
