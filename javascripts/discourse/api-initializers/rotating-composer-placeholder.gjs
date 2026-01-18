import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.0", (api) => {
  document.documentElement.setAttribute(
    "data-rotating-composer-placeholder-loaded",
    "1"
  );

  const FALLBACK = ["Write your reply…"];

  let pmObserver = null;
  let pmWaitObserver = null;
  let pmWaitTimeout = null;
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

  // ---------- Markdown ----------
  function setMarkdownPlaceholder(text) {
    const els = Array.from(document.querySelectorAll("textarea.d-editor-input"));
    if (!els.length) return false;
    els.forEach((el) => el.setAttribute("placeholder", text));
    return true;
  }

  // ---------- Rich (ProseMirror) ----------
  function findProseMirrorRoot() {
    // Don’t over-specify – your DOM confirms this exact class exists
    return document.querySelector(".ProseMirror.d-editor-input");
  }

  function applyProseMirrorPlaceholder(text) {
    const pm = findProseMirrorRoot();
    if (!pm) return false;

    const p = pm.querySelector("p[data-placeholder]") || pm.querySelector("p");
    if (!p) return false;

    // overwrite the REAL attribute Discourse uses for the watermark
    if (p.getAttribute("data-placeholder") !== text) {
      p.setAttribute("data-placeholder", text);
    }

    // a11y label is safe on the root (and we know it sticks)
    if (pm.getAttribute("aria-label") !== text) {
      pm.setAttribute("aria-label", text);
    }

    return p.getAttribute("data-placeholder") === text;
  }

  function cleanupRichPin() {
    if (pmObserver) {
      pmObserver.disconnect();
      pmObserver = null;
    }
    if (pmWaitObserver) {
      pmWaitObserver.disconnect();
      pmWaitObserver = null;
    }
    if (pmWaitTimeout) {
      clearTimeout(pmWaitTimeout);
      pmWaitTimeout = null;
    }
    pinnedText = null;
  }

  function attachPmObserver(pmEl) {
    if (pmObserver) pmObserver.disconnect();

    pmObserver = new MutationObserver(() => {
      if (pinnedText) applyProseMirrorPlaceholder(pinnedText);
    });

    pmObserver.observe(pmEl, {
      subtree: true,
      childList: true,
      attributes: true,
      // Discourse/PM may rewrite class + data-placeholder repeatedly
      attributeFilter: ["data-placeholder", "class"],
    });

    // Apply immediately once observer is attached
    if (pinnedText) {
      applyProseMirrorPlaceholder(pinnedText);
      setTimeout(() => applyProseMirrorPlaceholder(pinnedText), 50);
      setTimeout(() => applyProseMirrorPlaceholder(pinnedText), 150);
      setTimeout(() => applyProseMirrorPlaceholder(pinnedText), 500);
    }
  }

  function waitForProseMirrorAndPin(text) {
    pinnedText = text;

    // Try immediately
    const now = findProseMirrorRoot();
    if (now) {
      attachPmObserver(now);
      return;
    }

    // Otherwise wait briefly for PM to mount, then attach
    if (pmWaitObserver) pmWaitObserver.disconnect();

    pmWaitObserver = new MutationObserver(() => {
      const pm = findProseMirrorRoot();
      if (!pm) return;

      // Found it — stop waiting and attach the real observer
      pmWaitObserver.disconnect();
      pmWaitObserver = null;

      attachPmObserver(pm);
    });

    pmWaitObserver.observe(document.body, {
      childList: true,
      subtree: true,
    });

    // Hard stop so we never “watch forever”
    if (pmWaitTimeout) clearTimeout(pmWaitTimeout);
    pmWaitTimeout = setTimeout(() => {
      if (pmWaitObserver) {
        pmWaitObserver.disconnect();
        pmWaitObserver = null;
      }
      pmWaitTimeout = null;
    }, 5000);
  }

  function applyRandomPlaceholder() {
    const placeholders = getPlaceholdersFromSettings();
    const text = pickRandom(placeholders);

    // Markdown still works
    setMarkdownPlaceholder(text);

    // Rich: wait until PM exists, then pin
    waitForProseMirrorAndPin(text);
  }

  function scheduleApply() {
    setTimeout(applyRandomPlaceholder, 0);
    setTimeout(applyRandomPlaceholder, 100);
    setTimeout(applyRandomPlaceholder, 400);
    setTimeout(applyRandomPlaceholder, 1200); // extra late pass for PM mount
  }

  api.onAppEvent("composer:opened", scheduleApply);
  api.onAppEvent("composer:inserted", scheduleApply);
  api.onAppEvent("composer:reply-reloaded", scheduleApply);
  api.onPageChange(scheduleApply);

  api.onAppEvent?.("composer:closed", cleanupRichPin);
});
