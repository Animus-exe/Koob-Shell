import Foundation

enum TrackerCommandInstaller {
    static func install() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: AppPaths.binDirectory, withIntermediateDirectories: true, attributes: nil)

        for (url, script) in commandScripts() {
            let data = Data(script.utf8)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
            try data.write(to: url, options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
    }

    static func commandScripts() -> [(URL, String)] {
        [
            (AppPaths.trackerCommandURL, trackerScript),
            (AppPaths.nativeHelpCommandURL, nativeHelpScript),
        ]
    }

    private static let trackerScript = """
    #!/bin/sh
    set -eu

    DB="$HOME/Library/Application Support/\(AppPaths.appName)/tracker.sqlite3"

    if ! command -v sqlite3 >/dev/null 2>&1; then
      echo "sqlite3 is required for the tracker command."
      exit 1
    fi

    if [ ! -f "$DB" ]; then
      echo "Tracker database not found yet. Launch \(AppPaths.displayName) once to create it."
      exit 1
    fi

    sql_escape() {
      printf "%s" "$1" | sed "s/'/''/g"
    }

    format_minutes() {
      minutes="$1"
      hours=$((minutes / 60))
      remainder=$((minutes % 60))
      if [ "$hours" -eq 0 ]; then
        printf "%sm" "$remainder"
      else
        printf "%sh %sm" "$hours" "$remainder"
      fi
    }

    match_type_for_cli() {
      case "$1" in
        process|executable|exec) printf '%s' 'executableName' ;;
        app|name|application) printf '%s' 'localizedName' ;;
        bundle|bundleid|bundle-id) printf '%s' 'bundleIdentifier' ;;
        *) return 1 ;;
      esac
    }

    cli_type_for_match() {
      case "$1" in
        executableName) printf '%s' 'process' ;;
        localizedName) printf '%s' 'app' ;;
        bundleIdentifier) printf '%s' 'bundle' ;;
        *) printf '%s' "$1" ;;
      esac
    }

    pick_color() {
      name="$1"
      sum="$(printf '%s' "$name" | cksum | awk '{print $1}')"
      idx=$((sum % 10))
      case "$idx" in
        0) printf '%s' '#F97316' ;;
        1) printf '%s' '#3B82F6' ;;
        2) printf '%s' '#10B981' ;;
        3) printf '%s' '#8B5CF6' ;;
        4) printf '%s' '#EF4444' ;;
        5) printf '%s' '#60A5FA' ;;
        6) printf '%s' '#06B6D4' ;;
        7) printf '%s' '#EC4899' ;;
        8) printf '%s' '#EAB308' ;;
        *) printf '%s' '#14B8A6' ;;
      esac
    }

    find_tools() {
      query="$1"
      escaped="$(sql_escape "$query")"
      sqlite3 -separator '|' "$DB" "
        SELECT id, display_name, match_type, match_value, color, is_enabled
        FROM tracked_tools
        WHERE lower(id) = lower('$escaped')
           OR lower(display_name) = lower('$escaped')
           OR lower(match_value) = lower('$escaped')
        ORDER BY display_name COLLATE NOCASE;
      "
    }

    require_one_match() {
      query="$1"
      rows="$(find_tools "$query")"
      if [ -z "$rows" ]; then
        echo "No tracked process matches '$query'."
        exit 1
      fi
      count="$(printf '%s\\n' "$rows" | grep -c . || true)"
      if [ "$count" -gt 1 ]; then
        echo "Multiple matches for '$query':"
        printf '%s\\n' "$rows" | while IFS='|' read -r id name match_type match_value color is_enabled; do
          printf '  %s (%s)\\n' "$name" "$(cli_type_for_match "$match_type")"
        done
        exit 1
      fi
      printf '%s\\n' "$rows"
    }

    run_status_query() {
      mode="$1"
      if [ "$mode" = "running" ]; then
        filter="AND COALESCE(runtime.is_running, 0) = 1"
      else
        filter=""
      fi

      sqlite3 -separator '|' "$DB" "
        WITH totals AS (
          SELECT
            tool_id,
            COALESCE(SUM(CASE WHEN local_date = date('now', 'localtime') THEN counted_open ELSE 0 END), 0) AS today_minutes,
            COALESCE(SUM(counted_open), 0) AS total_minutes
          FROM tool_minutes
          GROUP BY tool_id
        )
        SELECT
          tools.display_name,
          COALESCE(runtime.is_running, 0),
          COALESCE(runtime.current_run_minutes, 0),
          COALESCE(totals.today_minutes, 0),
          COALESCE(totals.total_minutes, 0)
        FROM tracked_tools AS tools
        LEFT JOIN tool_runtime_state AS runtime ON runtime.tool_id = tools.id
        LEFT JOIN totals ON totals.tool_id = tools.id
        WHERE tools.is_enabled = 1
        $filter
        ORDER BY COALESCE(runtime.is_running, 0) DESC, tools.display_name COLLATE NOCASE;
      "
    }

    print_status() {
      mode="$1"
      rows="$(run_status_query "$mode")"
      if [ -z "$rows" ]; then
        if [ "$mode" = "running" ]; then
          echo "No tracked processes are running right now."
        else
          echo "No enabled tracked processes yet. Try: tracker add <process>"
        fi
        exit 0
      fi

      if [ "$mode" = "running" ]; then
        echo "Running now"
      else
        echo "Tracked processes"
      fi

      printf '%s\\n' "$rows" | while IFS='|' read -r name is_running current today total; do
        if [ "$is_running" = "1" ]; then
          state="live $(format_minutes "$current")"
        else
          state="idle"
        fi

        printf '%-20s  %s  today %s  total %s\\n' \\
          "$name" \\
          "$state" \\
          "$(format_minutes "$today")" \\
          "$(format_minutes "$total")"
      done
    }

    cmd_list() {
      rows="$(sqlite3 -separator '|' "$DB" "
        SELECT display_name, match_type, match_value, is_enabled
        FROM tracked_tools
        ORDER BY display_name COLLATE NOCASE;
      ")"
      if [ -z "$rows" ]; then
        echo "No tracked processes yet. Try: tracker add <process>"
        exit 0
      fi

      echo "All tracked processes"
      printf '%s\\n' "$rows" | while IFS='|' read -r name match_type match_value is_enabled; do
        if [ "$is_enabled" = "1" ]; then
          state="on"
        else
          state="off"
        fi
        printf '%-20s  %-7s  %-8s  %s\\n' \\
          "$name" \\
          "$state" \\
          "$(cli_type_for_match "$match_type")" \\
          "$match_value"
      done
    }

    cmd_add() {
      value=""
      display=""
      type="process"

      while [ "$#" -gt 0 ]; do
        case "$1" in
          --as)
            [ "$#" -ge 2 ] || { echo "Missing value for --as"; exit 1; }
            display="$2"
            shift 2
            ;;
          --type)
            [ "$#" -ge 2 ] || { echo "Missing value for --type"; exit 1; }
            type="$2"
            shift 2
            ;;
          -h|--help)
            cat <<'EOF'
    tracker add <target> [--as <name>] [--type process|app|bundle]

    Examples
      tracker add node
      tracker add node --as Node.js
      tracker add Safari --type app
      tracker add com.apple.Safari --type bundle
    EOF
            exit 0
            ;;
          -*)
            echo "Unknown option: $1"
            exit 1
            ;;
          *)
            if [ -n "$value" ]; then
              echo "Unexpected argument: $1"
              exit 1
            fi
            value="$1"
            shift
            ;;
        esac
      done

      if [ -z "$value" ]; then
        echo "Usage: tracker add <process> [--as <name>] [--type process|app|bundle]"
        exit 1
      fi

      if ! match_type="$(match_type_for_cli "$type")"; then
        echo "Unknown type '$type'. Use process, app, or bundle."
        exit 1
      fi

      if [ -z "$display" ]; then
        display="$(basename "$value")"
      fi

      existing="$(sqlite3 "$DB" "
        SELECT COUNT(*) FROM tracked_tools
        WHERE lower(display_name) = lower('$(sql_escape "$display")')
           OR (match_type = '$(sql_escape "$match_type")'
               AND lower(match_value) = lower('$(sql_escape "$value")'));
      ")"
      if [ "$existing" != "0" ]; then
        echo "'$display' is already tracked."
        exit 1
      fi

      id="$(uuidgen | tr '[:upper:]' '[:lower:]')"
      color="$(pick_color "$display")"

      sqlite3 "$DB" "
        INSERT INTO tracked_tools (id, display_name, match_type, match_value, color, is_enabled)
        VALUES (
          '$(sql_escape "$id")',
          '$(sql_escape "$display")',
          '$(sql_escape "$match_type")',
          '$(sql_escape "$value")',
          '$(sql_escape "$color")',
          1
        );
      "

      echo "Tracking $display ($(cli_type_for_match "$match_type")=$value)"
      echo "Time starts counting while \(AppPaths.displayName) is open."
    }

    cmd_remove() {
      if [ "$#" -lt 1 ]; then
        echo "Usage: tracker remove <name>"
        exit 1
      fi

      row="$(require_one_match "$1")"
      id="$(printf '%s' "$row" | cut -d'|' -f1)"
      name="$(printf '%s' "$row" | cut -d'|' -f2)"

      sqlite3 "$DB" "
        BEGIN;
        DELETE FROM tool_minutes WHERE tool_id = '$(sql_escape "$id")';
        DELETE FROM tool_runtime_state WHERE tool_id = '$(sql_escape "$id")';
        DELETE FROM tracked_tools WHERE id = '$(sql_escape "$id")';
        COMMIT;
      "
      echo "Stopped tracking $name"
    }

    cmd_set_enabled() {
      enabled="$1"
      shift
      if [ "$#" -lt 1 ]; then
        if [ "$enabled" = "1" ]; then
          echo "Usage: tracker enable <name>"
        else
          echo "Usage: tracker disable <name>"
        fi
        exit 1
      fi

      row="$(require_one_match "$1")"
      id="$(printf '%s' "$row" | cut -d'|' -f1)"
      name="$(printf '%s' "$row" | cut -d'|' -f2)"

      sqlite3 "$DB" "UPDATE tracked_tools SET is_enabled = $enabled WHERE id = '$(sql_escape "$id")';"
      if [ "$enabled" = "1" ]; then
        echo "Enabled $name"
      else
        echo "Disabled $name"
      fi
    }

    mode="${1:-help}"
    if [ "$#" -gt 0 ]; then
      shift
    fi

    case "$mode" in
      help|-h|--help)
        cat <<'EOF'
    Track any process or macOS app — not just coding tools.

    tracker add <process> [--as <name>] [--type process|app|bundle]
    tracker remove <name>     Stop tracking a process or app
    tracker list              List all tracked entries (including disabled)
    tracker enable <name>     Resume tracking
    tracker disable <name>    Pause tracking without deleting history
    tracker status            Show enabled entries and time totals
    tracker running           Show only entries running right now
    tracker help              Show this help

    Types
      process   Match a process executable name (default), e.g. node, python3
      app       Match a macOS app display name, e.g. Safari
      bundle    Match a bundle identifier, e.g. com.apple.Safari

    Examples
      tracker add node
      tracker add node --as Node.js
      tracker add nginx
      tracker add Safari --type app
      tracker add com.apple.dt.Xcode --type bundle --as Xcode
      tracker disable Docker Desktop
      tracker remove node
    EOF
        ;;
      status|running)
        print_status "$mode"
        ;;
      list|ls)
        cmd_list
        ;;
      add)
        cmd_add "$@"
        ;;
      remove|rm|delete)
        cmd_remove "$@"
        ;;
      enable|on)
        cmd_set_enabled 1 "$@"
        ;;
      disable|off)
        cmd_set_enabled 0 "$@"
        ;;
      *)
        echo "Unknown tracker command: $mode"
        echo
        "$0" help
        exit 1
        ;;
    esac
    """

    private static let nativeHelpScript = """
    #!/bin/sh
    set -eu

    cat <<'EOF'
    \(AppPaths.displayName) native commands

    App commands
    -help             Show this help screen

    Process tracking
    Track any process or macOS app — not just coding tools.

    tracker add <process> [--as <name>] [--type process|app|bundle]
    tracker remove <name>     Stop tracking a process or app
    tracker list              List all tracked entries (including disabled)
    tracker enable <name>     Resume tracking
    tracker disable <name>    Pause tracking without deleting history
    tracker status            Show enabled entries and time totals
    tracker running           Show only entries running right now
    tracker help              Show tracker command help

    Types
      process   Match a process executable name (default), e.g. node, python3
      app       Match a macOS app display name, e.g. Safari
      bundle    Match a bundle identifier, e.g. com.apple.Safari

    Examples
      tracker add node
      tracker add node --as Node.js
      tracker add nginx
      tracker add Safari --type app
      tracker add com.apple.dt.Xcode --type bundle --as Xcode
      tracker disable Docker Desktop
      tracker remove node

    Common shell commands
    pwd               Print the current folder
    ls                List files in the current folder
    cd <folder>       Move to another folder
    cd ..             Go up one folder
    clear             Clear the terminal screen
    open .            Open the current folder in Finder
    whoami            Show the current macOS user

    Tips
    - These run inside a real login shell, so standard zsh commands and tools work too.
    - The tracker command is added to this app's private PATH automatically.
    - Time is recorded in minute buckets while \(AppPaths.displayName) is open.
    EOF
    """
}
