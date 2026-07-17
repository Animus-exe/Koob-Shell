# Koob Shell

[![CI](https://github.com/vurzumm/mac-terminal-tracker/actions/workflows/ci.yml/badge.svg)](https://github.com/vurzumm/mac-terminal-tracker/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

`Koob Shell` is a lightweight native macOS terminal app built with SwiftUI.

This repository (`mac-terminal-tracker`) is the SwiftPM source for the **Koob Shell** app. The executable product is named `KoobShell`.

## Features

- a Terminal.app-style window with **in-app tabs** (multiple independent shell sessions)
- a live shell session backed by a PTY (via [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm))
- **10,000-line scrollback** and **Find** (⌘F / ⌘G)
- safer **paste** with line-ending normalization and multi-line confirmation
- themes, plugins, and an optional [ASCII art gallery](Plugins/ascii-gallery/Ascii_art/README.md) (bring your own art — personal files stay local / gitignored)
- SQLite-backed **process time tracking** for any process or app
- optional **Workflow Intelligence** session capture

## Requirements

- macOS 14 or later
- Swift 6 toolchain
- `sqlite3` (used by the bundled `tracker` CLI)

## Quick start

```bash
git clone https://github.com/vurzumm/mac-terminal-tracker.git
cd mac-terminal-tracker
swift run
```

Run tests:

```bash
swift test
```

Tests live under `Tests/` and are gitignored — they stay on your machine and are not uploaded with the repo.

## Documentation

| Guide | Description |
| --- | --- |
| [docs/getting-started.md](docs/getting-started.md) | Build, run, shortcuts, first launch |
| [docs/configuration.md](docs/configuration.md) | App Support files, themes, preferences |
| [docs/tracker.md](docs/tracker.md) | Track any process or app |
| [docs/plugins.md](docs/plugins.md) | Plugin manifest format |
| [ASCII Gallery](Plugins/ascii-gallery/Ascii_art/README.md) | Add your own gallery art |
| [docs/workflow-intelligence.md](docs/workflow-intelligence.md) | Session capture and `koobshell` |
| [docs/architecture.md](docs/architecture.md) | Project layout for contributors |

Full index: [docs/README.md](docs/README.md)

## Quick reference

| Shortcut | Action |
| --- | --- |
| ⌘T | New tab |
| ⌘W | Close tab (closes the window when the last tab is closed) |
| ⌘F | Find in scrollback |
| ⌘G / ⇧⌘G | Find next / previous |
| ⌘V | Paste (confirms multi-line pastes) |

```bash
-help
tracker help
tracker add node
tracker status
```

Config and data live in `~/Library/Application Support/KoobShell/`.

## Notes

- Local-only: no sync, privilege elevation, or remote jobs.
- Tabs keep inactive shells running; each tab has its own workflow session ID.
- macOS window tabbing is disabled in favor of in-app tabs.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Bug reports and feature requests: [open an issue](https://github.com/vurzumm/mac-terminal-tracker/issues).

## Security

See [SECURITY.md](SECURITY.md) for how to report vulnerabilities.

## License

MIT — see [LICENSE](LICENSE). Third-party dependencies: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Created by [vurzumm](https://github.com/vurzumm).
