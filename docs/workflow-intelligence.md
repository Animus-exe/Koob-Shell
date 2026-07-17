# Workflow Intelligence

Workflow Intelligence is an optional plugin that records shell commands per terminal tab, classifies risk, tracks related git file changes, and can generate summaries and rollback plans.

It is enabled when the `workflow-intelligence` plugin is present and `isEnabled` is true.

## What you get

- Per-tab workflow session IDs (`KOOBSHELL_SESSION_ID` / `TERM_SESSION_ID`)
- Shell hooks for **zsh** and **bash** that call `koobshell record-start` / `record-end`
- Session inspector panel in the main window
- `koobshell` CLI on the session `PATH`

## `koobshell` commands

```bash
koobshell help
koobshell explain [last|session-id]
koobshell undo [last-risky] [--apply]
koobshell replay [last|session-id]
koobshell show-why-failed [last]
koobshell debug-report [--format md|json|text]
koobshell session list
koobshell session search <query>
```

| Command | Purpose |
| --- | --- |
| `explain` | Summary of a session (goal, outcome, commands, files, rollback) |
| `undo` | Print a rollback plan; add `--apply` to run it (destructive) |
| `replay` | Print commands as a replay script |
| `show-why-failed` | Focus on the last failed command |
| `debug-report` | Package a report (`md`, `json`, or `text`) |
| `session list` / `search` | Browse recent sessions |

Plugin command templates also expose common actions (for example `koobshell explain last`).

## Preferences

Workflow settings (also in Preferences when the plugin is active):

- **Capture enabled** — record commands
- **Auto summary on exit** — write a summary when a tab’s shell ends
- **Destructive warnings** — `off`, `warn`, or `confirm` (confirm is not a hard block today; warnings are advisory)

Rules live under the plugin’s `rules/` directory:

- `destructive-commands.json`
- `goal-patterns.json`
- `rollback-templates.json`

## Data

Workflow tables live in the same `tracker.sqlite3` database (`workflow_sessions`, `workflow_commands`, `workflow_file_changes`, `workflow_rollback_plans`).

Closing a tab closes that tab’s workflow session only; other tabs keep capturing.

## Shell support

Hooks are installed for zsh (`ZDOTDIR` overlay) and bash (`--rcfile` overlay). Other shells will not get automatic capture unless you integrate them yourself.
