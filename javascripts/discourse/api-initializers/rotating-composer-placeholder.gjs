import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.0", (api) => {
  const FALLBACK = ["Write your reply…"];

  function pickRandom(arr) {
    return arr[Math.floor(Math.random() * arr.length)];
  }

  function setComposerPlaceholderWithRetries(text) {
    let tries = 0;
    const maxTries = 15;
    const delayMs = 80;

    const attempt = () => {
      tries += 1;

      const all = Array.from(document.querySelectorAll("textarea"));
      const editorAll = Array.from(document.querySelectorAll("textarea.d-editor-input"));

      // eslint-disable-next-line no-console
      console.log(
        `[rotating-composer-placeholder] try ${tries}`,
        { totalTextareas: all.length, editorTextareas: editorAll.length },
        editorAll.map((t) => ({
          placeholder: t.getAttribute("placeholder"),
          inComposer: !!t.closest(".composer"),
          visible: t.offsetParent !== null,
          classes: t.className
        }))
      );

      // Prefer visible composer editor textarea
      const el =
        editorAll.find((t) => t.closest(".composer") && t.offsetParent !== null) ||
        editorAll[0];

      if (el) {
        el.setAttribute("placeholder", text);
        return;
      }

      if (tries < maxTries) setTimeout(attempt, delayMs);
    };

    attempt();
  }


  function normalizePlaceholders(value) {
    if (Array.isArray(value)) {
      return value.map((v) => String(v).trim()).filter(Boolean);
    }

    if (typeof value === "string") {
      return value
        .split(/\r?\n|,|\|/g) // include pipe separator
        .map((s) => s.trim())
        .filter(Boolean);
    }

    return [];
  }

  function getPlaceholdersFromSettings() {
    const raw = normalizePlaceholders(settings?.rotating_placeholders);
    return raw.length ? raw : FALLBACK;
  }

  function applyRandomPlaceholder() {
    const placeholders = getPlaceholdersFromSettings();
    setComposerPlaceholderWithRetries(pickRandom(placeholders));
    // eslint-disable-next-line no-console
    console.log("[rotating-composer-placeholder] composer opened, settings:", settings?.rotating_placeholders);
  }

  api.onAppEvent("composer:opened", () => {
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
});

