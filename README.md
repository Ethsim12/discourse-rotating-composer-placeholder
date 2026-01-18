# discourse-rotating-composer-placeholder (Theme Component) 

A small Discourse **theme component** that rotates the composer textarea placeholder each time the composer opens (a “carousel” of helpful prompts).

## What it does

- Replaces the composer textarea placeholder with a **random** entry from a configurable list.
- Rotates on:
  - opening the composer (reply / new topic composer opening)
  - reloading a reply into the composer
- All configuration is done via **theme component settings** (no plugin required).

---

## Install

1. In Discourse Admin, go to:  
   **Admin → Appearance → Themes & components → Components → 3 dots**

2. Click **Install**.

3. Choose **From a git repository**.

4. Paste this repository URL and click **Install**.

---

## Enable the theme component

Installing a theme component does **not** activate it automatically.  
You must attach it to a theme.

1. Go to:  
   **Admin → Appearance → Themes & components → Components → Rotating Composer Placeholder**

2. Click your **active theme** (for example: “Default”, “Desktop”, or your custom theme).

3. Press the Green Tick Box.

4. Refresh your browser.

Once added, the component will immediately apply to that theme.

---

## Configure the component

1. Still within the theme component's page.

3. Edit the `rotating_placeholders` list.

Example values:

- `What did you try? Include steps to reproduce.`
- `One idea per reply. If it’s a new issue, start a new topic.`
- `Please include: expected result, actual result, and any errors.`
- `Tip: paste logs inside ```triple backticks```.`

Notes:

- Each list entry becomes a possible placeholder.
- Empty entries are ignored.
- If the list is empty, the component falls back to a default placeholder.

---

## Compatibility

- Designed for modern Discourse installs using theme `api-initializers`.
- Recommended minimum Discourse version: **3.2.0**.

---

## Known limitations

- This is a **client-side UI enhancement only**.
- Placeholder text does not affect what is posted.
- The placeholder rotates **when the composer opens**, not continuously.
- If `js.composer.reply_placeholder` is overridden in  
  **Admin → Appearance → Site texts**, this component will still replace it when active.

---

## Support / contributions

- Issues and pull requests are welcome.
- Please include your Discourse version and steps to reproduce.

---

## License

Please see MIT-type License in `LICENSE`.
