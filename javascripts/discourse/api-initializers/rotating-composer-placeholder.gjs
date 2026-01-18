import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.0", (api) => {
  const FALLBACK = ["Write your reply…"];

  // keep one observer per page lifetime
  let pmObserver = null;
  let pmObserverStopTimer = null;

  function pickRandom(arr) {
    return arr[Math.floor(Math.random() * arr.length)];
  }

  function normalizePlaceholders(value) {
    if (Array.isArray(value)) {
      return value.map((v) => String(v).trim()).filter(Boolean);
    }

    if (typeof value === "string") {
      return value
        .split(/\r?\n|,|\|/g) // newline, comma, or pipe
        .map((s) => s.trim())
        .filter(Boolean);
    }

    return [];
  }

  function getPlaceholdersFromSettings() {
    const raw = normalizePlaceholders(settings?.rotating_placeholders);
    return raw.length ? raw : FALLBACK;
  }

  function cleanupProseMirrorPin() {
    if (pmObserver) {
      pmObserver.disconnect();
      pmObserver = null;
    }
    if (pmObserverStopTimer) {
      clearTimeout(pmObserverStopTimer);
      pmObserverStopTimer = null;
    }
  }

  // ---------------- Markdown (textarea) ----------------
  function setMarkdownPlaceholder(text) {
    const els = Array.from(document.querySelectorAll("textarea.d-editor-input"));
    if (!els.length) return false;

    els.forEach((el) => el.setAttribute("placeholder", text));
    return true;
  }

  // ---------------- Rich Text (ProseMirror) ----------------
  function isProseMirrorEmpty(pmEl) {
    // ProseMirror is "empty" when it contains only the trailing break / empty paragraph
    // This is conservative and avoids pinning while user has content.
    const txt = (pmEl.textContent || "").replace(/\u200B/g, "").trim();
    return txt.length === 0;
  }

  function setProseMirrorPlaceholder(text) {
    const pmEl = document.querySelector(
      ".d-editor .ProseMirror.d-editor-input[contenteditable='true']"
    );
    if (!pmEl) return false;

    // Only pin while empty; otherwise leave it alone
    if (!isProseMirrorEmpty(pmEl)) return true;

    // Discourse’s visible watermark comes from the existing attribute:
    // <p data-placeholder="...">
    const p =
      pmEl.querySelector("p[data-placeholder]") ||
      pmEl.querySelector("p") ||
      null;

    if (!p) return false;

    // Overwrite the *existing* attribute Discourse CSS already reads.
    p.setAttribute("data-placeholder", text);

    // accessibility
    pmEl.setAttribute("aria-label", text);

    return true;
  }

  function ensureProseMirrorPinned(text) {
    cleanupProseMirrorPin();

    // Apply immediately + a couple of delayed passes to beat late init/toggles
    setProseMirrorPlaceholder(text);
    setTimeout(() => setProseMirrorPlaceholder(text), 50);
    setTimeout(() => setProseMirrorPlaceholder(text), 150);
    setTimeout(() => setProseMirrorPlaceholder(text), 400);

    const pmEl = document.querySelector(
      ".d-editor .ProseMirror.d-editor-input[contenteditable='true']"
    );
    if (!pmEl) return;

    // Re-apply if Discourse/PM re-writes placeholder during mount/toggle.
    pmObserver = new MutationObserver(() => {
      // stop pinning once user types something
      if (!isProseMirrorEmpty(pmEl)) {
        cleanupProseMirrorPin();
        return;
      }
      setProseMirrorPlaceholder(text);
    });

    pmObserver.observe(pmEl, {
      subtree: true,
      childList: true,
      attributes: true,
      attributeFilter: ["class", "data-placeholder"],
    });

    // hard stop so we never keep observers around forever
    pmObserverStopTimer = setTimeout(() => cleanupProseMirrorPin(), 5000);
  }

  function applyRandomPlaceholder() {
    const placeholders = getPlaceholdersFromSettings();
    const text = pickRandom(placeholders);

    // markdown is cheap and safe
    setMarkdownPlaceholder(text);

    // rich text needs pinning (but bounded + auto-disconnect)
    ensureProseMirrorPinned(text);
  }

  // In 2026.x, "opened" may happen before the editor DOM exists,
  // so schedule a few attempts (very small number).
  function scheduleApply() {
    setTimeout(applyRandomPlaceholder, 0);
    setTimeout(applyRandomPlaceholder, 120);
    setTimeout(applyRandomPlaceholder, 450);
  }

  api.onAppEvent("composer:inserted", scheduleApply);
  api.onAppEvent("composer:reply-reloaded", scheduleApply);
  api.onAppEvent("composer:opened", scheduleApply);

  api.onAppEvent?.("composer:closed", () => {
    cleanupProseMirrorPin();
  });

  api.onPageChange(() => {
    cleanupProseMirrorPin();
  });
});
