# Configuration

All user configuration lives under:

```text
~/Library/Application Support/KoobShell/
```

| Path | Purpose |
| --- | --- |
| `appearance.json` | Active theme, gallery options, color overrides, custom themes |
| `commands.json` | User command definitions (merged with plugin commands) |
| `plugins/<id>/plugin.json` | Enabled plugin manifests and assets |
| `plugins/<id>/…` | Plugin-specific files (rules, art, shell hooks, CLI) |
| `bin/tracker` | Process tracking CLI (reinstalled on app launch) |
| `bin/-help` | In-terminal help command |
| `bin/koobshell` | Workflow Intelligence CLI (when that plugin is active) |
| `tracker.sqlite3` | Process minutes, runtime state, and workflow sessions |

Older installs under `MacTerminalTracker` are migrated automatically on launch.

## Appearance

`appearance.json` controls:

- `activeThemeID` — selected theme (built-in, custom, or plugin)
- `allowPluginThemes` / `allowPluginGalleries`
- `customThemes` — themes defined only on this machine
- `colorOverrides`, `borderOverrides`, `titleBarOverrides`
- Gallery options: `galleryEnabled`, `galleryOpacity`, `galleryFullScreen`, `galleryIntervalSeconds`, `galleryRevolve`
- `terminalOpacity`

Prefer the Preferences window for day-to-day changes. Edit JSON only when you need something the UI does not expose.

## Commands

`commands.json` and plugin `commands` entries share the same shape: a display name, shell `template` (with optional `{{arg}}` placeholders), and optional environment / working directory.

Command packs are loaded into the registry today; a command palette UI is not required to use templates from the shell (type the command yourself, or use plugin-provided CLIs such as `koobshell`).

## Themes and gallery

Themes may set colors, font, padding, optional startup banner text, and border / title-bar styles.

The ASCII gallery plugin can show rotating art behind a semi-transparent terminal. Art files live in the plugin’s art directory (JSON payloads or plain text).

**Personal art is gitignored** — your pieces under `Plugins/ascii-gallery/Ascii_art/` stay local and are not uploaded to GitHub. For formats, paths, Preferences settings, and a copy-paste template, see [Plugins/ascii-gallery/Ascii_art/README.md](../Plugins/ascii-gallery/Ascii_art/README.md).