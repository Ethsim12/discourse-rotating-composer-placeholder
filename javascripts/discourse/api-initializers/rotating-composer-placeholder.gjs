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

  // Rich (ProseMirror) — update the *real* placeholder attribute on <p>
  function setProseMirrorPlaceholderOnce(text) {
    const pmRoots = Array.from(
      document.querySelectorAll(".ProseMirror.d-editor-input")
    );
    if (!pmRoots.length) return false;

    let ok = false;

    pmRoots.forEach((pmEl) => {
      pmEl.setAttribute("data-rcp-root", "1");

      const p = pmEl.querySelector("p[data-placeholder]") || pmEl.querySelector("p");
      if (!p) return;

      // Overwrite the actual placeholder attribute Discourse displays
      p.setAttribute("data-placeholder", text);
      pmEl.setAttribute("aria-label", text);

      if (p.getAttribute("data-placeholder") === text) ok = true;
    });

    return ok;
  }

  function applyRichWithRetries(text) {
    let tries = 0;
    const maxTries = 80; // ~6.4s
    const delayMs = 80;

    const tick = () => {
      tries += 1;
      if (setProseMirrorPlaceholderOnce(text)) return;
      if (tries < maxTries) setTimeout(tick, delayMs);
    };

    tick();
    setTimeout(() => setProseMirrorPlaceholderOnce(text), 150);
    setTimeout(() => setProseMirrorPlaceholderOnce(text), 500);
    setTimeout(() => setProseMirrorPlaceholderOnce(text), 1200);
    setTimeout(() => setProseMirrorPlaceholderOnce(text), 2500);
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
