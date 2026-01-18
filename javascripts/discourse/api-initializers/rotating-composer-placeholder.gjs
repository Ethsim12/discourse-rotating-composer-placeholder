import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.0", (api) => {
  const FALLBACK = ["Write your reply…"];

  let pmAttrObserver = null;
  let pmChildObserver = null;
  let pmStopTimer = null;

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

  function cleanupRichWatchers() {
    if (pmAttrObserver) {
      pmAttrObserver.disconnect();
      pmAttrObserver = null;
    }
    if (pmChildObserver) {
      pmChildObserver.disconnect();
      pmChildObserver = null;
    }
    if (pmStopTimer) {
      clearTimeout(pmStopTimer);
      pmStopTimer = null;
    }
  }

  function getProseMirrorEl() {
    return document.querySelector(
      ".d-editor .ProseMirror.d-editor-input[contenteditable='true']"
    );
  }

  function setMarkdownPlaceholder(text) {
    const el = document.querySelector(".d-editor textarea.d-editor-input");
    if (!el) return false;
    el.setAttribute("placeholder", text);
    return true;
  }

  function setProseMirrorPlaceholderOnce(pmEl, text) {
    const p = pmEl?.querySelector("p");
    if (!p) return false;

    p.setAttribute("data-placeholder", text);
    pmEl.setAttribute("aria-label", text);
    return true;
  }

  function watchAndPinProseMirrorPlaceholder(pmEl, text) {
    cleanupRichWatchers();

    // Apply immediately + a couple of delayed passes (cheap, no loops)
    setProseMirrorPlaceholderOnce(pmEl, text);
    setTimeout(() => setProseMirrorPlaceholderOnce(pmEl, text), 80);
    setTimeout(() => setProseMirrorPlaceholderOnce(pmEl, text), 250);
    setTimeout(() => setProseMirrorPlaceholderOnce(pmEl, text), 700);

    // We only observe the placeholder attribute on the <p> (very low cost)
    let corrections = 0;
    const maxCorrections = 30;

    const attachToParagraph = (pEl) => {
      if (!pEl) return;

      // Ensure correct value before observing
      if (pEl.getAttribute("data-placeholder") !== text) {
        pEl.setAttribute("data-placeholder", text);
      }

      pmAttrObserver = new MutationObserver(() => {
        if (corrections >= maxCorrections) {
          cleanupRichWatchers();
          return;
        }

        const currentP = pmEl.querySelector("p");
        if (!currentP) return;

        const cur = currentP.getAttribute("data-placeholder");
        if (cur !== text) {
          corrections += 1;

          // Disconnect BEFORE writing to avoid self-trigger loops
          pmAttrObserver.disconnect();
          currentP.setAttribute("data-placeholder", text);
          // Re-attach to the (possibly same) paragraph
          attachToParagraph(currentP);
        }
      });

      pmAttrObserver.observe(pEl, {
        attributes: true,
        attributeFilter: ["data-placeholder"],
      });
    };

    // If ProseMirror replaces the <p>, reattach
    pmChildObserver = new MutationObserver(() => {
      const pNow = pmEl.querySelector("p");
      if (!pNow) return;

      // If observer not attached (or was cleaned), reattach
      if (!pmAttrObserver) {
        attachToParagraph(pNow);
        return;
      }

      // If it’s a new paragraph node, reattach cleanly
      // (cheap check: if current observer is on old node, we just reattach anyway)
      pmAttrObserver.disconnect();
      attachToParagraph(pNow);
    });

    // ProseMirror’s <p> is a direct child in your HTML, so subtree:false is enough
    pmChildObserver.observe(pmEl, { childList: true });

    // Initial attach
    attachToParagraph(pmEl.querySelector("p"));

    // Stop all watching after a short window (prevents long-lived observers)
    pmStopTimer = setTimeout(() => {
      cleanupRichWatchers();
    }, 5000);
  }

  function setComposerPlaceholder(text) {
    // Markdown
    if (setMarkdownPlaceholder(text)) return true;

    // Rich editor (ProseMirror)
    const pmEl = getProseMirrorEl();
    if (pmEl) {
      watchAndPinProseMirrorPlaceholder(pmEl, text);
      return true;
    }

    return false;
  }

  function applyWithRetries(text) {
    let tries = 0;
    const maxTries = 12;

    const tick = () => {
      tries += 1;

      const ok = setComposerPlaceholder(text);
      if (ok) return;

      if (tries < maxTries) setTimeout(tick, 80);
    };

    tick();
  }

  function applyRandomPlaceholder() {
    const placeholders = getPlaceholdersFromSettings();
    const text = pickRandom(placeholders);

    cleanupRichWatchers();
    applyWithRetries(text);
  }

  api.onAppEvent("composer:inserted", () => {
    try {
      applyRandomPlaceholder();
    } catch (e) {
      // eslint-disable-next-line no-console
      console.warn("[rotating-composer-placeholder] failed:", e);
    }
  });

  api.onAppEvent("composer:reply-reloaded", () => {
    try {
      applyRandomPlaceholder();
    } catch (e) {
      // eslint-disable-next-line no-console
      console.warn("[rotating-composer-placeholder] failed:", e);
    }
  });

  api.onAppEvent?.("composer:closed", () => {
    cleanupRichWatchers();
  });
});
