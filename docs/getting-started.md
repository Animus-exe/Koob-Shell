# Getting started

## Requirements

- macOS 14 or later
- Swift 6 toolchain (`swift` on your `PATH`)
- `sqlite3` (used by the `tracker` CLI)

## Build and run

From the repository root:

```bash
swift run
```

Run tests (local only — `Tests/` is gitignored and not in the public repo):

```bash
swift test
```

The executable product is named `KoobShell`.

## First launch

On first launch, Koob Shell seeds local data under:

```text
~/Library/Application Support/KoobShell/
```

That includes `appearance.json`, `commands.json`, plugin manifests, the `tracker` / `-help` scripts in `bin/`, and `tracker.sqlite3`.

In-terminal help:

```bash
-help
tracker help
```

## Terminal basics

Koob Shell embeds a real login shell over a PTY (via [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)).

| Shortcut | Action |
| --- | --- |
| ⌘T | New tab |
| ⌘W | Close tab (closes the window when the last tab is closed) |
| ⌘F | Find in scrollback |
| ⌘G / ⇧⌘G | Find next / previous |
| ⌘C / ⌘V / ⌘A | Copy / paste / select all |

Notes:

- Scrollback is 10,000 lines.
- Multi-line paste asks for confirmation and normalizes Windows/classic Mac line endings.
- Inactive tabs keep their shells running in the background.
- macOS window tabbing is disabled; use in-app tabs instead.

## Preferences

Open **Preferences…** from the terminal context menu (or the app menu when available) to adjust themes, terminal opacity, ASCII gallery options, and Workflow Intelligence settings.

To add your own gallery backdrops, see [Adding your own ASCII art](../Plugins/ascii-gallery/Ascii_art/README.md). Your art files are gitignored so they are not uploaded with the repo.

## Local-only

Koob Shell does not sync data, elevate privileges, or run remote jobs. Everything stays on your Mac.
