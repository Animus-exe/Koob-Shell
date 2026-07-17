# Architecture

Koob Shell is a SwiftPM executable (`KoobShell`) targeting macOS 14+, built with SwiftUI and AppKit, embedding [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) for the PTY terminal surface.

## Layout

```text
Sources/MacTerminalTracker/
  App/           App entry, preferences window
  ViewModels/    AppViewModel, TerminalSessionManager
  Views/         Terminal, tabs, inspector, chrome, preferences
  Services/      Stores, tracker, workflow, plugins, paste helpers
  Models/        Codable configs, themes, sessions, paths
  Resources/     Default JSON seeds
Plugins/         Bundled plugin sources (seeded into App Support)
Tests/           Local Swift Testing unit tests (gitignored)
docs/            User and contributor documentation
```

## Runtime model

**Shared (process-wide)**

- Appearance, commands, plugins, themes, gallery
- `ActivityDatabase` / `tracker.sqlite3`
- `ToolTrackerService` (process polling)
- `WorkflowPluginRuntime` (active workflow plugin + rules)

**Per tab (`TerminalSession`)**

- Title, cwd, shell running state
- Distinct `workflowSessionID`
- Own `TerminalTextView` / PTY (kept alive when the tab is hidden)

`TerminalSessionManager` owns the tab list. Closing the last tab closes the window.

## Terminal surface

`TrackerTerminalView` subclasses SwiftTerm’s `LocalProcessTerminalView`:

- Login shell with optional workflow overlays on `PATH` / `ZDOTDIR`
- Scrollback raised to 10,000 lines
- Paste normalization and multi-line confirmation
- Find via SwiftTerm’s built-in find bar (Edit menu / context menu)

`ActiveTerminalRegistry` points menu actions (copy, paste, find) at the selected tab’s terminal.

## Tracking

`ToolTrackerService` reloads tools from SQLite, matches GUI apps and process names, and writes minute rows plus runtime state. The `tracker` shell script reads/writes the same database so CLI management works without a separate IPC channel.

## Workflow

When Workflow Intelligence is active, each tab opens a workflow session in SQLite. Shell hooks invoke `koobshell` with the tab’s session id. The inspector shows recent sessions and follows the selected tab’s active session when present.

## Testing

```bash
swift test
```

The `Tests/` directory is gitignored and not published with the repo. Locally it covers session management, paste helpers, tracker matching, plugins, appearance, gallery layout, and workflow rules/database behavior. There are no UI automation tests yet. CI verifies `swift build` on macOS.
