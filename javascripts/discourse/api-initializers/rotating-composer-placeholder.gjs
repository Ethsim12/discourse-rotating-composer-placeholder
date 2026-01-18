import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.0", (api) => {
  const FALLBACK = ["Write your reply…"];

  let pmObserver = null;
  let pmInterval = null;
  let pmTimeout = null;
  let pinnedText = null;

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

  function cleanupRichPin() {
    if (pmObserver) {
      pmObserver.disconnect();
      pmObserver = null;
    }
    if (pmInterval) {
      clearInterval(pmInterval);
      pmInterval = null;
    }
    if (pmTimeout) {
      clearTimeout(pmTimeout);
      pmTimeout = null;
    }
    pinnedText = null;
  }

  function getProseMirrorEl() {
    return document.querySelector(
      ".d-editor .ProseMirror.d-editor-input[contenteditable='true']"
    );
  }

  function setProseMirrorPlaceholder(text) {
    const pmEl = getProseMirrorEl();
    if (!pmEl) return false;

    const p = pmEl.querySelector("p");
    if (!p) return false;

    // The visible watermark on your build is this attribute:
    p.setAttribute("data-placeholder", text);

    // Nice-to-have accessibility:
    pmEl.setAttribute("aria-label", text);

    return true;
  }

  function pinProseMirrorPlaceholder(text) {
    pinnedText = text;

    // 1) Apply immediately + a few delayed passes (beats init order)
    setProseMirrorPlaceholder(text);
    setTimeout(() => setProseMirrorPlaceholder(text), 50);
    setTimeout(() => setProseMirrorPlaceholder(text), 150);
    setTimeout(() => setProseMirrorPlaceholder(text), 400);
    setTimeout(() => setProseMirrorPlaceholder(text), 800);

    // 2) Observe changes under the rich editor and re-apply if it flips back
    if (pmObserver) pmObserver.disconnect();
    pmObserver = new MutationObserver(() => {
      // Re-query each time (ProseMirror can recreate nodes)
      const pmEl = getProseMirrorEl();
      const p = pmEl?.querySelector("p");
      if (!p) return;

      if (p.getAttribute("data-placeholder") !== pinnedText) {
        p.setAttribute("data-placeholder", pinnedText);
      }
    });

    // Observe the editor subtree; no attributeFilter (Discourse may mutate many attrs)
    const pmElNow = getProseMirrorEl();
    if (pmElNow) {
      pmObserver.observe(pmElNow, { subtree: true, childList: true, attributes: true });
    }

    // 3) Timer pin for a short window (covers “late placeholder set” hooks)
    if (pmInterval) clearInterval(pmInterval);
    pmInterval = setInterval(() => {
      setProseMirrorPlaceholder(pinnedText);
    }, 100);

    if (pmTimeout) clearTimeout(pmTimeout);
    pmTimeout = setTimeout(() => {
      // After init settles, stop the interval; observer stays (cheap) to catch rare flips
      if (pmInterval) {
        clearInterval(pmInterval);
        pmInterval = null;
      }
    }, 2000);
  }

  function setMarkdownPlaceholder(text) {
    const el = document.querySelector(".d-editor textarea.d-editor-input");
    if (!el) return false;
    el.setAttribute("placeholder", text);
    return true;
  }

  function applyRandomPlaceholder() {
    const placeholders = getPlaceholdersFromSettings();
    const text = pickRandom(placeholders);

    // Try markdown first
    if (setMarkdownPlaceholder(text)) return;

    // Otherwise pin rich editor placeholder
    pinProseMirrorPlaceholder(text);
  }

  // Rich editor can mount “after inserted” in a couple of frames; retry lightly.
  function applyWithRetries() {
    let tries = 0;
    const maxTries = 10;

    const tick = () => {
      tries += 1;
      applyRandomPlaceholder();

      // If neither markdown nor PM exists yet, keep trying briefly
      const hasMarkdown = !!document.querySelector(".d-editor textarea.d-editor-input");
      const hasPM = !!getProseMirrorEl();

      if ((hasMarkdown || hasPM) || tries >= maxTries) return;
      setTimeout(tick, 80);
    };

    tick();
  }

  api.onAppEvent("composer:inserted", () => {
    try {
      cleanupRichPin();
      applyWithRetries();
    } catch (e) {
      // eslint-disable-next-line no-console
      console.warn("[rotating-composer-placeholder] failed:", e);
    }
  });

  api.onAppEvent("composer:reply-reloaded", () => {
    try {
      cleanupRichPin();
      applyWithRetries();
    } catch (e) {
      // eslint-disable-next-line no-console
      console.warn("[rotating-composer-placeholder] failed:", e);
    }
  });

  api.onAppEvent?.("composer:closed", () => {
    cleanupRichPin();
  });
});
