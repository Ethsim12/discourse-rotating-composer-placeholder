import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.0", (api) => {
  const FALLBACK = ["Write your reply…"];
  let pmObserver = null;

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

  function findEditorElement() {
    const root = document.querySelector(".d-editor");
    if (!root) return null;

    const textarea = root.querySelector("textarea.d-editor-input");
    if (textarea) return { kind: "textarea", el: textarea, root };

    const pm = root.querySelector(
      ".ProseMirror.d-editor-input[contenteditable='true']"
    );
    if (pm) return { kind: "prosemirror", el: pm, root };

    return null;
  }

  function applyProseMirrorPlaceholder(pmEl, text) {
    // Set on the ProseMirror root too (some CSS reads from here)
    pmEl.setAttribute("data-placeholder", text);
    pmEl.setAttribute("aria-label", text);

    // ProseMirror/Discourse uses <p data-placeholder="..."> for the visible watermark
    const p =
      pmEl.querySelector("p.is-empty[data-placeholder]") ||
      pmEl.querySelector("p[data-placeholder]") ||
      pmEl.querySelector("p");

    if (p) p.setAttribute("data-placeholder", text);
  }

  function ensureProseMirrorObserver(pmEl, text) {
    if (pmObserver) pmObserver.disconnect();

    pmObserver = new MutationObserver(() => {
      applyProseMirrorPlaceholder(pmEl, text);
    });

    pmObserver.observe(pmEl, {
      subtree: true,
      childList: true,
      attributes: true,
      attributeFilter: ["data-placeholder", "class"],
    });

    // Apply immediately + a couple of delayed passes during editor init
    applyProseMirrorPlaceholder(pmEl, text);
    setTimeout(() => applyProseMirrorPlaceholder(pmEl, text), 150);
    setTimeout(() => applyProseMirrorPlaceholder(pmEl, text), 500);
  }

  function setComposerPlaceholder(text) {
    const found = findEditorElement();
    if (!found) return false;

    if (found.kind === "textarea") {
      found.el.setAttribute("placeholder", text);
      return true;
    }

    if (found.kind === "prosemirror") {
      ensureProseMirrorObserver(found.el, text);
      return true;
    }

    return false;
  }

  function setComposerPlaceholderWithRetries(text) {
    let tries = 0;
    const maxTries = 15;
    const delayMs = 80;

    const attempt = () => {
      tries += 1;
      const ok = setComposerPlaceholder(text);
      if (ok) return;
      if (tries < maxTries) setTimeout(attempt, delayMs);
    };

    attempt();
  }

  function applyRandomPlaceholder() {
    const placeholders = getPlaceholdersFromSettings();
    setComposerPlaceholderWithRetries(pickRandom(placeholders));
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

  // Optional cleanup if the event exists on your build
  api.onAppEvent?.("composer:closed", () => {
    if (pmObserver) {
      pmObserver.disconnect();
      pmObserver = null;
    }
  });
});
