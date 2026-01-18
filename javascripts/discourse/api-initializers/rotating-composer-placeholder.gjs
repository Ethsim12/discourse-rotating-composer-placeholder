import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.0", (api) => {
  // PROOF this file is loaded (remove later)
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

  // ---------------- Markdown (textarea) ----------------
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

  // ---------------- Rich (ProseMirror) ----------------
  function setProseMirrorPlaceholderOnCurrentDom(text) {
    const pmRoots = Array.from(
      document.querySelectorAll(".ProseMirror.d-editor-input")
    );
    if (!pmRoots.length) return false;

    let changed = false;

    pmRoots.forEach((pmEl) => {
      // Set a debug marker on the root so we can prove we touched it
      pmEl.setAttribute("data-rcp-root", "1");

      // Target ALL placeholder paragraphs we can see (more robust than just the first p)
      const ps = Array.from(pmEl.querySelectorAll("p"));
      ps.forEach((p) => {
        // Only bother if it looks like the placeholder paragraph (has data-placeholder or is empty-ish)
        const hasCorePlaceholder = p.hasAttribute("data-placeholder");
        if (!hasCorePlaceholder && ps.length > 1) return;

        p.setAttribute("data-rotating-placeholder", text);

        if (p.getAttribute("data-rotating-placeholder") === text) {
          changed = true;
        }
      });

      pmEl.setAttribute("aria-label", text);
    });

    return changed;
  }

  // Short burst over a few animation frames to beat ProseMirror settling/replacement
  function applyRichBurst(text) {
    const maxFrames = 12; // bounded: ~200ms worst case
    let frame = 0;

    const step = () => {
      frame += 1;
      setProseMirrorPlaceholderOnCurrentDom(text);
      if (frame < maxFrames) requestAnimationFrame(step);
    };

    requestAnimationFrame(step);
  }

  function applyRichWithRetries(text) {
    // A few delayed “wins” + a RAF burst each time
    applyRichBurst(text);

    setTimeout(() => applyRichBurst(text), 80);
    setTimeout(() => applyRichBurst(text), 200);
    setTimeout(() => applyRichBurst(text), 500);
    setTimeout(() => applyRichBurst(text), 1200);
    setTimeout(() => applyRichBurst(text), 2500);

    // One tiny log so you can confirm rich roots are found (should not spam)
    // eslint-disable-next-line no-console
    console.info("[rotating-composer-placeholder] PM roots:",
      document.querySelectorAll(".ProseMirror.d-editor-input").length
    );
  }

  function applyRandomPlaceholder() {
    const placeholders = getPlaceholdersFromSettings();
    const text = pickRandom(placeholders);

    // Apply to both (safe, bounded)
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
