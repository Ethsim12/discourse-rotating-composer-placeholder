import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.0", (api) => {
  function pickRandom(arr) {
    return arr[Math.floor(Math.random() * arr.length)];
  }

  function setComposerPlaceholder(text) {
  requestAnimationFrame(() => {
    const el = document.querySelector(".d-editor-input");
    if (el) {
      el.setAttribute("placeholder", text);
    }
  });
}

  function getPlaceholdersFromSettings() {
    // settings.rotating_placeholders is a theme setting (list)
    const raw = (settings?.rotating_placeholders || []).filter(Boolean);
    return raw.length ? raw : ["Write your reply…"];
  }

  api.onAppEvent("composer:opened", () => {
    const placeholders = getPlaceholdersFromSettings();
    setComposerPlaceholder(pickRandom(placeholders));
  });

  api.onAppEvent("composer:reply-reloaded", () => {
    const placeholders = getPlaceholdersFromSettings();
    setComposerPlaceholder(pickRandom(placeholders));
  });
});
