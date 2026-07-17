# Process tracking

Koob Shell records how long tracked processes and apps are open, in **one-minute buckets**, while the app is running.

Seeded defaults include common coding tools (Cursor, VS Code, Terminal, iTerm, Warp, Xcode, Docker Desktop). You can track **any** process or macOS app.

## Commands

These are installed on `PATH` inside Koob Shell sessions (`~/Library/Application Support/KoobShell/bin`).

```bash
tracker help
tracker add <process> [--as <name>] [--type process|app|bundle]
tracker remove <name>
tracker list
tracker enable <name>
tracker disable <name>
tracker status
tracker running
```

| Command | Purpose |
| --- | --- |
| `tracker add <target>` | Start tracking a process (default), app name, or bundle id |
| `tracker remove <name>` | Stop tracking and delete that entry’s history |
| `tracker list` | List all entries, including disabled ones |
| `tracker enable` / `disable` | Resume or pause tracking without deleting history |
| `tracker status` | Enabled entries with today / total time |
| `tracker running` | Only entries that are live right now |

Names for `remove` / `enable` / `disable` match display name, match value, or tool id.

## Match types

| `--type` | Matches | Example |
| --- | --- | --- |
| `process` (default) | Process executable basename | `tracker add node` |
| `app` | macOS app display name | `tracker add Safari --type app` |
| `bundle` | Bundle identifier | `tracker add com.apple.dt.Xcode --type bundle --as Xcode` |

Optional `--as` sets the display name:

```bash
tracker add node --as Node.js
tracker add nginx
tracker add python3 --as Python
```

## How matching works

- **Process** entries use the system process list (`ps`) and GUI app executables, case-insensitively.
- **App** / **bundle** entries use `NSWorkspace` running applications.
- The app reloads the tool list on each poll (about every 30 seconds), so CLI changes apply while Koob Shell is open.

## Data

Stored in `tracker.sqlite3`:

- `tracked_tools` — what to watch
- `tool_minutes` — one row per tool per minute open
- `tool_runtime_state` — live / idle and current-run minutes for `tracker status`

Time only accumulates while Koob Shell is running and polling.
