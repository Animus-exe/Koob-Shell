<div align="center">

# Koob Shell

[![CI](https://github.com/Animus-exe/Koob-Shell/actions/workflows/ci.yml/badge.svg)](https://github.com/Animus-exe/Koob-Shell/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Star this repo](https://img.shields.io/github/stars/Animus-exe/Koob-Shell?style=social)](https://github.com/Animus-exe/Koob-Shell)

[![ORC Torrent](https://img.shields.io/badge/ORC%20Torrent-BitTorrent%20client-111111?style=for-the-badge&logo=github&logoColor=white)](https://github.com/The-animus-project/Orc-Torrent)

```text
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣀⣤⣤⣿⣿⣿⣿⣿⣤⣤⣀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⡀⣀⣀⣤⣤⣶⣶⢶⡿⣿⣟⣿⣻⢿⣽⣳⣟⣾⣳⢯⣟⣿⣻⢿⣿⣿⣶⣾⣤⣶⣤⣤⣀⣀⠀⠀⠀
⣿⣿⣿⡿⣿⣽⣞⡵⣯⢯⡽⣶⢻⡶⢯⣟⣾⣳⣟⡾⣽⣻⣞⡷⣯⡿⣞⣷⣯⣟⣿⣻⣽⣿⣿⣿⣿⣿⡗
⢸⣿⣳⡻⣭⢻⡜⡻⢗⢯⢿⣵⢯⣟⣟⡾⣵⣻⢾⣽⣳⣟⡾⣽⢷⣻⣟⣾⣷⣿⣾⣿⣿⣿⣿⣿⣿⣿⡇
⢸⣷⣏⠷⣭⣓⢮⡱⢍⠲⣀⠎⡉⠘⠋⠟⠷⢯⣟⣾⣳⣯⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇
⠰⣿⣎⡟⡶⣩⠖⡱⢊⡱⢠⢂⠡⠊⠄⠀⠀⠀⠈⣽⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠃
⠀⣿⢼⡹⢖⡣⡝⢢⠣⡐⠡⢂⠐⢀⠂⠀⠁⠀⠀⣽⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀
⠀⣟⢧⡏⢧⡓⣌⠣⢒⠡⢁⠂⠌⠀⠀⠀⠀⠀⠀⣽⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀
⠀⢹⣳⢚⡥⢓⠬⡑⠌⢂⠁⠂⠄⠀⠀⠀⠀⠀⠀⣼⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡏⠀
⠀⢸⣇⠯⡜⣡⠚⠤⢉⡐⢈⠀⡀⠀⠀⠀⠀⠀⠀⢼⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀
⠀⢨⣝⡚⠴⣡⠊⡔⠡⢀⠂⠀⠀⠀⠀⠀⠀⠀⠀⢺⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀
⠀⢈⡧⣍⠳⣀⠣⠄⡁⠂⠀⠀⠀⠀⠀⠀⠀⠀⠀⢺⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠆⠀
⠀⠀⡷⣌⠣⢄⠃⠌⡀⠠⠁⠀⠀⠀⠀⠀⠀⠀⠀⢹⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠃⠀
⠀⠀⡷⣌⠣⡌⢌⠂⠄⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⢺⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀
⠀⠀⠙⡾⣗⡸⣂⠱⡈⢄⠂⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠋⠀⠀
⠀⠀⠀⠈⠘⠹⣳⢧⡑⢦⠐⠠⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠛⠉⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠈⠀⢹⠓⣬⠑⡄⠀⠀⠀⠀⠀⠀⣼⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠋⠁⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠑⠫⣟⠶⣌⡀⢀⠀⠀⠀⣸⣿⣿⣿⣿⣿⣿⡿⠛⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠺⢽⣦⣄⣀⠀⣿⣿⣿⣿⡿⠛⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠙⠓⠹⠟⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
```

**Koob Shell** is a heavily customisable native terminal for macOS.

The point of the project is not another fixed-feature terminal — it is a base you shape yourself. New capabilities ship as **plugins**, so you can mix themes, visuals, and tools and effectively **build your own terminal**: highly visually customisable, and just as customisable in what it can do.

This repository is the SwiftPM source for Koob Shell. The executable product is named `KoobShell`.

## Features

- a real PTY shell (via [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)) with **in-app tabs** and **split panes**
- **10,000-line scrollback**, Find (⌘F / ⌘G), and safer paste (line-ending normalisation + multi-line confirmation)
- **plugin-first** extensibility — themes, commands, gallery art, and workflow tools load from plugin manifests
- bundled plugins today: [Shell Theme Pack](Plugins/shell-theme-pack/plugin.json), [ASCII Gallery](Ascii_art/README.md), [Workflow Intelligence](docs/workflow-intelligence.md)
- SQLite-backed **process time tracking** for any process or app (`tracker`)

## Requirements

- macOS 14 or later
- Swift 6 toolchain
- `sqlite3` (used by the bundled `tracker` CLI)

## Quick start

```bash
git clone https://github.com/Animus-exe/Koob-Shell.git
cd Koob-Shell
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
| [ASCII Gallery](Ascii_art/README.md) | Drop art in `Ascii_art/` |
| [docs/workflow-intelligence.md](docs/workflow-intelligence.md) | Session capture and `koobshell` |
| [docs/architecture.md](docs/architecture.md) | Project layout for contributors |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute (plugins, core, PRs) |

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

Want to help? See the full guide: **[CONTRIBUTING.md](CONTRIBUTING.md)**.

Short version: prefer shipping new capabilities as **plugins**, keep PRs focused, and open an [issue](https://github.com/Animus-exe/Koob-Shell/issues) for bugs or ideas.

## Security

See [SECURITY.md](SECURITY.md) for how to report vulnerabilities.

## License

MIT — see [LICENSE](LICENSE). Third-party dependencies: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Created by [vurzumm](https://github.com/vurzumm).

</div>
