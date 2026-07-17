# Contributing to Koob Shell

Thanks for helping shape Koob Shell. The goal of this project is a **heavily customisable macOS terminal** — new capabilities ship as **plugins**, so people can build their own look and toolset instead of waiting on a fixed feature set.

This guide covers how to set up the project, where to put changes, how to author plugins, and how we review pull requests.

## Ways to contribute

| Kind of work | Where it usually lands |
| --- | --- |
| Themes, commands, gallery art, workflow rules | A plugin under [`Plugins/`](Plugins/) (preferred for new user-facing features) |
| Core terminal (tabs, splits, PTY, paste, find, Preferences chrome) | [`Sources/KoobShell/`](Sources/KoobShell/) |
| Docs, examples, CI | [`docs/`](docs/), root markdown, [`.github/`](.github/) |
| Bug reports / feature ideas | [GitHub Issues](https://github.com/Animus-exe/Koob-Shell/issues) |

If you are unsure whether something should be a plugin or core, open an issue first. Prefer plugins when the feature can be enabled, disabled, or swapped without changing the terminal engine.

## Before you start

1. Read [docs/architecture.md](docs/architecture.md) for layout and runtime model.
2. Skim [docs/plugins.md](docs/plugins.md) — plugin-first is the main extension path.
3. Browse [docs/](docs/) for tracker, configuration, and workflow behaviour.
4. Search existing issues and pull requests to avoid duplicate work.

## Development setup

**Requirements**

- macOS 14 or later
- Swift 6 toolchain (`swift` on your `PATH`)
- `sqlite3` (used by the bundled `tracker` CLI)

**Clone and run**

```bash
git clone https://github.com/Animus-exe/Koob-Shell.git
cd mac-terminal-tracker
swift run
```

Build only:

```bash
swift build
```

The executable product is named `KoobShell`. Local data lives in:

```text
~/Library/Application Support/KoobShell/
```

Bundled plugins under `Plugins/` are seeded into `~/Library/Application Support/KoobShell/plugins/` on first launch. After that, Preferences edits (including plugin on/off) update the App Support copy.

### Tests

`Tests/` is **gitignored** and not published with the repo. If you keep a local `Tests/KoobShellTests` tree, run:

```bash
swift test
```

before opening a pull request. CI still runs `swift build` on macOS for every PR.

### Portable build (optional)

```bash
./scripts/package.sh 0.001.0
```

Produces `dist/Koob Shell.app` and a DMG. Useful when validating packaging or sharing a smoke-test binary — not required for every PR.

## Project map

```text
Sources/KoobShell/   App, views, view models, services, models
Plugins/             Bundled plugin sources (seeded into App Support)
docs/                User and contributor documentation
scripts/package.sh   App + DMG packaging
Tests/               Local unit tests (gitignored)
```

See [docs/architecture.md](docs/architecture.md) for the runtime model (shared stores vs per-tab / per-pane sessions).

## Contributing a plugin (preferred for new features)

Plugins are folders with a `plugin.json` manifest. They can contribute:

- **themes** — colours, fonts, borders, title bar
- **commands** — shell templates
- **gallery** — ASCII backdrop art
- **workflow** — session capture / `koobshell` hooks (advanced)

### Steps

1. Copy an existing folder under [`Plugins/`](Plugins/) as a starting point.
2. Give it a unique `id` and a clear `name` / `version`.
3. Set `"isEnabled": true` (users can toggle this in **Preferences → Plugins**).
4. Develop against the seeded copy in App Support, or delete that folder and relaunch so your repo `Plugins/` copy is re-seeded.
5. Document what the plugin does (short note in [docs/plugins.md](docs/plugins.md) if it ships bundled).

Manifest shape and examples: [docs/plugins.md](docs/plugins.md).  
Gallery art formats: [Ascii_art/README.md](Ascii_art/README.md) (drop personal art in `Ascii_art/`).

**Do not commit personal ASCII art** unless you intend it to be public. Personal gallery files are gitignored on purpose.

## Contributing to core

1. Create a branch from `main`.
2. Keep the change focused — one concern per PR when possible.
3. Match naming and style in the files you touch.
4. Prefer small SwiftUI / AppKit changes over large refactors unless the PR is explicitly a refactor.
5. Update docs when behaviour changes (shortcuts, Preferences, plugins, tracker, packaging).
6. Add or update local tests when you change non-UI logic and have a local `Tests/` tree.

### Areas that are sensitive

- `TerminalTextView` / PTY lifecycle and `TerminalHostRegistry` (splits must not tear down live shells)
- `ActivityDatabase` / tracker schema
- Workflow shell hooks and `PATH` / `ZDOTDIR` overlays
- App Support migration (`AppPaths.migrateLegacyAppSupportIfNeeded`)

Call those out in the PR description and test manually on a clean App Support folder when you can.

## Pull requests

Use the pull request template and include:

- **What** changed and **why**
- How you tested (build, manual steps, screenshots for UI)
- Whether docs need a follow-up (or link the doc update in the same PR)

CI runs `swift build` on macOS. Please make sure that passes locally too.

## Reporting bugs

Use the bug report issue template and include:

- macOS version
- Swift version (`swift --version`)
- Steps to reproduce
- Expected vs actual behaviour
- Whether plugins were enabled/disabled (Preferences → Plugins)

Feature requests: use the feature request template. For “build your own terminal” ideas, say whether you imagine it as a **plugin** or **core** change.

## Code style (light rules)

- Prefer clarity over cleverness.
- Keep user-facing strings consistent with existing Preferences / menu copy.
- Do not add network sync, privilege elevation, or remote plugin marketplaces without discussion — Koob Shell is local-only by design.
- Do not force-add gitignored personal art or secrets.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE). Copyright (c) vurzumm.

## Questions

Open an issue, or start a draft PR with a clear summary. Related project: [ORC Torrent](https://github.com/The-animus-project/Orc-Torrent).
