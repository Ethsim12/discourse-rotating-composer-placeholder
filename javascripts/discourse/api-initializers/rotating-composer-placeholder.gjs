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

    // Markdown editor
    const textarea = root.querySelector("textarea.d-editor-input");
    if (textarea) return { kind: "textarea", el: textarea };

    // Rich editor (ProseMirror)
    const pm = root.querySelector(
      ".ProseMirror.d-editor-input[contenteditable='true']"
    );
    if (pm) return { kind: "prosemirror", el: pm };

    return null;
  }

  function applyProseMirrorPlaceholder(pmEl, text) {
    // Root attributes (accessibility + some themes)
    pmEl.setAttribute("data-placeholder", text);
    pmEl.setAttribute("aria-label", text);

    // Visible watermark lives on the first paragraph
    const p =
      pmEl.querySelector("p.is-empty[data-placeholder]") ||
      pmEl.querySelector("p[data-placeholder]") ||
      pmEl.querySelector("p");

    if (p) {
      p.setAttribute("data-placeholder", text);
    }
  }

  function ensureProseMirrorObserver(pmEl, text) {
    if (pmObserver) pmObserver.disconnect();

    pmObserver = new MutationObserver(() => {
      const p = pmEl.querySelector("p");
      if (p && p.getAttribute("data-placeholder") !== text) {
        p.setAttribute("data-placeholder", text);
      }
    });

    // Watch the editor subtree because ProseMirror recreates nodes
    pmObserver.observe(pmEl, {
      subtree: true,
      childList: true,
      attributes: true,
    });

    // Initial + delayed applications to beat editor init
    applyProseMirrorPlaceholder(pmEl, text);
    setTimeout(() => applyProseMirrorPlaceholder(pmEl, text), 150);
    setTimeout(() => applyProseMirrorPlaceholder(pmEl, text), 500);
    setTimeout(() => applyProseMirrorPlaceholder(pmEl, text), 1200);
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

  api.onAppEvent?.("composer:closed", () => {
    if (pmObserver) {
      pmObserver.disconnect();
      pmObserver = null;
    }
  });
});
