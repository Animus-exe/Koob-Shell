# Changelog

All notable changes to **Koob Shell** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims to follow [Semantic Versioning](https://semver.org/).

## [0.001.0] — 2026-07-18

Portable release: `dist/Koob Shell.app` and `dist/KoobShell-0.001.0.dmg`.

### Added

- **Split panes** — up to **4 panes per tab**, via context menu or shortcuts:
  - ⌘D — split vertically (side by side)
  - ⇧⌘D — split horizontally (stacked)
  - ⇧⌘W — close focused pane
- Recursive pane layout (`HSplitView` / `VSplitView`) with focus tracking per pane
- `TerminalHostRegistry` so PTY hosts survive SwiftUI split/unsplit layout changes
- Each pane gets its own workflow session ID when Workflow Intelligence is active

### Changed

- Main window is a **normal terminal UI** — Workflow Intelligence side inspector removed from the layout (`inspectorPanelEnabled` defaults to off)
- Source module renamed from `MacTerminalTracker` → `KoobShell`
- Packaging default version set to `0.001.0`
- Thinner chrome / lighter UI pass for a sleeker daily-driver feel

### Fixed

- Terminal hosts re-parent cleanly across splits instead of being torn down and recreated

---

## [0.2.0] — 2026-07 (pre-release development)

Cumulative work from the first public-ready Koob Shell line through open-source prep. Earlier prototypes were named **Orc Shell** and **InK Shell**; app support folders still migrate from those legacy names.

### Added — Core terminal

- Native macOS 14+ SwiftUI app with a PTY shell via [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
- In-app **tabs** (⌘T / ⌘W); inactive shells keep running; macOS window tabbing disabled
- **10,000-line scrollback** and Find (⌘F / ⌘G / ⇧⌘G)
- Safer paste: line-ending normalization and multi-line confirmation
- Preferences window for themes, opacity, gallery, and workflow settings
- Custom window chrome (theme background, shell border, title-bar styling)

### Added — Process tracker

- SQLite-backed minute-bucket time tracking while the app is running
- Bundled `tracker` CLI on session `PATH` (`add` / `remove` / `list` / `enable` / `disable` / `status` / `running`)
- Track **any** process, app name, or bundle ID (not only coding tools)
- Seeded defaults for Cursor, VS Code, Terminal, iTerm, Warp, Xcode, Docker Desktop
- In-terminal `-help` / `tracker help` documentation

### Added — Plugins

- Plugin manifest system (`plugin.json`) with themes, commands, gallery, and workflow contributions
- **Shell Theme Pack** — Aurora Shell, Ember Rim, Frost Glass; dual-color borders, opacity, color depth, and title-bar gradients
- **ASCII Gallery** — cycling backdrop art, fullscreen-aware layout scaling, bring-your-own art (personal files gitignored)
- **Workflow Intelligence** — per-session command capture, risk classification, git-aware context, rollback plans, and `koobshell` CLI (`explain`, `undo`, `replay`, `show-why-failed`, `debug-report`, session list/search)
- Sample **Git Helper Pack** command templates

### Added — Packaging & open source

- `scripts/package.sh` — release binary → `Koob Shell.app` → DMG installer (ad-hoc codesign; universal when toolchain allows)
- Docs under `docs/` (getting started, configuration, tracker, plugins, workflow, architecture)
- MIT license, security policy, contributing guide, third-party notices
- GitHub issue/PR templates and CI (`swift build` on macOS)
- Credit and branding: **Koob Shell** by [vurzumm](https://github.com/vurzumm)
- Local `Tests/` gitignored; App Support under `~/Library/Application Support/KoobShell/`

---

## Notes

| Artifact | Path |
| --- | --- |
| App bundle | `dist/Koob Shell.app` |
| Installer | `dist/KoobShell-0.001.0.dmg` |
| Bundle version | `0.001.0` |

Requirements: macOS 14+, Swift 6 toolchain, `sqlite3`.
