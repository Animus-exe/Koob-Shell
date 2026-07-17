# Contributing to Koob Shell

Thank you for your interest in contributing. Koob Shell is a native macOS terminal built with SwiftUI, SwiftTerm, and SQLite.

## Before you start

- Read [docs/architecture.md](docs/architecture.md) for project layout and runtime model.
- Browse [docs/](docs/) for feature-specific behavior (tracking, plugins, workflow intelligence).
- Search existing issues and pull requests to avoid duplicate work.

## Development setup

Requirements:

- macOS 14 or later
- Swift 6 toolchain (`swift` on your `PATH`)
- `sqlite3` (used by the bundled `tracker` CLI)

```bash
git clone <your-fork-url>
cd mac-terminal-tracker
swift run
swift build
```

The executable product is named `KoobShell`. Local app data is written to `~/Library/Application Support/KoobShell/`. If you have a local `Tests/` checkout, run `swift test` before opening a pull request.

## Making changes

1. Create a branch from `main`.
2. Keep changes focused. Prefer small, reviewable pull requests.
3. Match existing code style and naming in the area you touch.
4. Add or update tests when behavior changes (keep them under the local `Tests/` directory; it is gitignored).
5. Update documentation when user-facing behavior changes.

Before opening a pull request, build (and run tests if you have them locally):

```bash
swift build
swift test
```

## Pull requests

Use the pull request template and include:

- What changed and why
- How you tested the change
- Screenshots or recordings for UI changes

CI runs `swift build` on macOS for every pull request.

## Reporting bugs

Use the bug report issue template and include:

- macOS version
- Swift version (`swift --version`)
- Steps to reproduce
- Expected vs actual behavior

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE). Copyright (c) vurzumm.
