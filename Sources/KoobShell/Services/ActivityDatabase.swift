import Foundation
import SQLite3

final class ActivityDatabase: @unchecked Sendable {
    private let dbPointer: OpaquePointer?
    private let queue = DispatchQueue(label: "KoobShell.ActivityDatabase")

    init(path: URL) throws {
        try FileManager.default.createDirectory(at: AppPaths.appSupportDirectory, withIntermediateDirectories: true, attributes: nil)

        var pointer: OpaquePointer?
        if sqlite3_open(path.path, &pointer) != SQLITE_OK {
            defer { sqlite3_close(pointer) }
            throw DatabaseError.open(message: String(cString: sqlite3_errmsg(pointer)))
        }
        dbPointer = pointer
        try initializeSchema()
    }

    deinit {
        sqlite3_close(dbPointer)
    }

    func seedTrackedToolsIfNeeded(_ tools: [TrackedTool]) throws {
        let existingCount = try queue.sync {
            try countRows(table: "tracked_tools")
        }
        if existingCount == 0 {
            try replaceTrackedTools(tools)
        }
    }

    func loadTrackedTools() throws -> [TrackedTool] {
        try queue.sync {
            let sql = "SELECT id, display_name, match_type, match_value, color, is_enabled FROM tracked_tools ORDER BY display_name;"
            let statement = try prepare(sql)
            defer { sqlite3_finalize(statement) }

            var tools: [TrackedTool] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                let idString = String(cString: sqlite3_column_text(statement, 0))
                let displayName = String(cString: sqlite3_column_text(statement, 1))
                let matchType = String(cString: sqlite3_column_text(statement, 2))
                let matchValue = String(cString: sqlite3_column_text(statement, 3))
                let color = String(cString: sqlite3_column_text(statement, 4))
                let isEnabled = sqlite3_column_int(statement, 5) == 1
                if let id = UUID(uuidString: idString), let toolMatchType = ToolMatchType(rawValue: matchType) {
                    tools.append(
                        TrackedTool(
                            id: id,
                            displayName: displayName,
                            matchType: toolMatchType,
                            matchValue: matchValue,
                            color: color,
                            isEnabled: isEnabled
                        )
                    )
                }
            }
            return tools
        }
    }

    func replaceTrackedTools(_ tools: [TrackedTool]) throws {
        try queue.sync {
            try execute("BEGIN TRANSACTION;")
            do {
                try execute("DELETE FROM tracked_tools;")
                let statement = try prepare(
                    "INSERT INTO tracked_tools (id, display_name, match_type, match_value, color, is_enabled) VALUES (?, ?, ?, ?, ?, ?);"
                )
                defer { sqlite3_finalize(statement) }

                for tool in tools {
                    sqlite3_reset(statement)
                    sqlite3_bind_text(statement, 1, tool.id.uuidString, -1, transientDestructor)
                    sqlite3_bind_text(statement, 2, tool.displayName, -1, transientDestructor)
                    sqlite3_bind_text(statement, 3, tool.matchType.rawValue, -1, transientDestructor)
                    sqlite3_bind_text(statement, 4, tool.matchValue, -1, transientDestructor)
                    sqlite3_bind_text(statement, 5, tool.color, -1, transientDestructor)
                    sqlite3_bind_int(statement, 6, tool.isEnabled ? 1 : 0)
                    if sqlite3_step(statement) != SQLITE_DONE {
                        throw DatabaseError.step(message: String(cString: sqlite3_errmsg(dbPointer)))
                    }
                }
                try execute("COMMIT;")
            } catch {
                try? execute("ROLLBACK;")
                throw error
            }
        }
    }

    func insertTrackedTool(_ tool: TrackedTool) throws {
        try queue.sync {
            let statement = try prepare(
                "INSERT INTO tracked_tools (id, display_name, match_type, match_value, color, is_enabled) VALUES (?, ?, ?, ?, ?, ?);"
            )
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, tool.id.uuidString, -1, transientDestructor)
            sqlite3_bind_text(statement, 2, tool.displayName, -1, transientDestructor)
            sqlite3_bind_text(statement, 3, tool.matchType.rawValue, -1, transientDestructor)
            sqlite3_bind_text(statement, 4, tool.matchValue, -1, transientDestructor)
            sqlite3_bind_text(statement, 5, tool.color, -1, transientDestructor)
            sqlite3_bind_int(statement, 6, tool.isEnabled ? 1 : 0)
            if sqlite3_step(statement) != SQLITE_DONE {
                throw DatabaseError.step(message: String(cString: sqlite3_errmsg(dbPointer)))
            }
        }
    }

    func findTrackedTools(matching query: String) throws -> [TrackedTool] {
        let tools = try loadTrackedTools()
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }

        if let id = UUID(uuidString: needle) {
            return tools.filter { $0.id == id }
        }

        return tools.filter {
            $0.displayName.caseInsensitiveCompare(needle) == .orderedSame
                || $0.matchValue.caseInsensitiveCompare(needle) == .orderedSame
        }
    }

    func deleteTrackedTool(id: UUID) throws {
        try queue.sync {
            try execute("BEGIN TRANSACTION;")
            do {
                for sql in [
                    "DELETE FROM tool_minutes WHERE tool_id = ?;",
                    "DELETE FROM tool_runtime_state WHERE tool_id = ?;",
                    "DELETE FROM tracked_tools WHERE id = ?;",
                ] {
                    let statement = try prepare(sql)
                    defer { sqlite3_finalize(statement) }
                    sqlite3_bind_text(statement, 1, id.uuidString, -1, transientDestructor)
                    if sqlite3_step(statement) != SQLITE_DONE {
                        throw DatabaseError.step(message: String(cString: sqlite3_errmsg(dbPointer)))
                    }
                }
                try execute("COMMIT;")
            } catch {
                try? execute("ROLLBACK;")
                throw error
            }
        }
    }

    func setTrackedToolEnabled(id: UUID, isEnabled: Bool) throws {
        try queue.sync {
            let statement = try prepare("UPDATE tracked_tools SET is_enabled = ? WHERE id = ?;")
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_int(statement, 1, isEnabled ? 1 : 0)
            sqlite3_bind_text(statement, 2, id.uuidString, -1, transientDestructor)
            if sqlite3_step(statement) != SQLITE_DONE {
                throw DatabaseError.step(message: String(cString: sqlite3_errmsg(dbPointer)))
            }
        }
    }

    func recordMinute(for toolIDs: Set<UUID>, at date: Date) throws {
        guard !toolIDs.isEmpty else { return }
        let minuteStart = Self.minuteStart(for: date)
        let localDate = Self.localDateString(for: date)

        try queue.sync {
            let statement = try prepare(
                "INSERT OR IGNORE INTO tool_minutes (tool_id, local_date, minute_start, counted_open) VALUES (?, ?, ?, 1);"
            )
            defer { sqlite3_finalize(statement) }

            for toolID in toolIDs {
                sqlite3_reset(statement)
                sqlite3_bind_text(statement, 1, toolID.uuidString, -1, transientDestructor)
                sqlite3_bind_text(statement, 2, localDate, -1, transientDestructor)
                sqlite3_bind_double(statement, 3, minuteStart.timeIntervalSince1970)
                if sqlite3_step(statement) != SQLITE_DONE {
                    throw DatabaseError.step(message: String(cString: sqlite3_errmsg(dbPointer)))
                }
            }
        }
    }

    func loadUsageSummaries(runningToolIDs: Set<UUID>, now: Date) throws -> [ToolUsageSummary] {
        let localDate = Self.localDateString(for: now)
        let tools = try loadTrackedTools()

        return try queue.sync {
            let statement = try prepare(
                """
                SELECT
                    t.id,
                    COALESCE(SUM(CASE WHEN m.local_date = ? THEN m.counted_open ELSE 0 END), 0) AS today_minutes,
                    COALESCE(SUM(m.counted_open), 0) AS total_minutes
                FROM tracked_tools t
                LEFT JOIN tool_minutes m ON m.tool_id = t.id
                GROUP BY t.id
                ORDER BY t.display_name;
                """
            )
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_text(statement, 1, localDate, -1, transientDestructor)

            var usageByID: [UUID: (Int, Int)] = [:]
            while sqlite3_step(statement) == SQLITE_ROW {
                let idString = String(cString: sqlite3_column_text(statement, 0))
                let todayMinutes = Int(sqlite3_column_int(statement, 1))
                let totalMinutes = Int(sqlite3_column_int(statement, 2))
                if let id = UUID(uuidString: idString) {
                    usageByID[id] = (todayMinutes, totalMinutes)
                }
            }

            return tools.map { tool in
                let counts = usageByID[tool.id] ?? (0, 0)
                return ToolUsageSummary(
                    id: tool.id,
                    displayName: tool.displayName,
                    color: tool.color,
                    todayMinutes: counts.0,
                    totalMinutes: counts.1,
                    isRunning: runningToolIDs.contains(tool.id)
                )
            }
        }
    }

    func loadCurrentRunMinutes(for toolIDs: Set<UUID>, now: Date) throws -> [UUID: Int] {
        guard !toolIDs.isEmpty else { return [:] }
        let currentMinute = Self.minuteStart(for: now).timeIntervalSince1970

        return try queue.sync {
            let statement = try prepare(
                "SELECT minute_start FROM tool_minutes WHERE tool_id = ? AND minute_start <= ? ORDER BY minute_start DESC;"
            )
            defer { sqlite3_finalize(statement) }

            var streaks: [UUID: Int] = [:]

            for toolID in toolIDs {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)
                sqlite3_bind_text(statement, 1, toolID.uuidString, -1, transientDestructor)
                sqlite3_bind_double(statement, 2, currentMinute)

                var expectedMinute = currentMinute
                var minutes = 0

                while sqlite3_step(statement) == SQLITE_ROW {
                    let minuteStart = sqlite3_column_double(statement, 0)
                    if minuteStart == expectedMinute {
                        minutes += 1
                        expectedMinute -= 60
                        continue
                    }

                    if minuteStart < expectedMinute {
                        break
                    }
                }

                streaks[toolID] = minutes
            }

            return streaks
        }
    }

    func updateRuntimeState(for tools: [TrackedTool], runningToolIDs: Set<UUID>, currentRunMinutes: [UUID: Int], observedAt: Date) throws {
        let observedAtTimestamp = observedAt.timeIntervalSince1970

        try queue.sync {
            try execute("BEGIN TRANSACTION;")
            do {
                let statement = try prepare(
                    """
                    INSERT INTO tool_runtime_state (tool_id, is_running, current_run_minutes, last_seen_at)
                    VALUES (?, ?, ?, ?)
                    ON CONFLICT(tool_id) DO UPDATE SET
                        is_running = excluded.is_running,
                        current_run_minutes = excluded.current_run_minutes,
                        last_seen_at = excluded.last_seen_at;
                    """
                )
                defer { sqlite3_finalize(statement) }

                for tool in tools {
                    sqlite3_reset(statement)
                    sqlite3_clear_bindings(statement)
                    sqlite3_bind_text(statement, 1, tool.id.uuidString, -1, transientDestructor)
                    sqlite3_bind_int(statement, 2, runningToolIDs.contains(tool.id) ? 1 : 0)
                    sqlite3_bind_int(statement, 3, Int32(currentRunMinutes[tool.id] ?? 0))
                    sqlite3_bind_double(statement, 4, observedAtTimestamp)
                    if sqlite3_step(statement) != SQLITE_DONE {
                        throw DatabaseError.step(message: String(cString: sqlite3_errmsg(dbPointer)))
                    }
                }

                try execute("COMMIT;")
            } catch {
                try? execute("ROLLBACK;")
                throw error
            }
        }
    }

    func openWorkflowSession(id: UUID, pluginID: String, projectRoot: String?, projectName: String?, startedAt: Date) throws {
        try queue.sync {
            let statement = try prepare(
                """
                INSERT OR IGNORE INTO workflow_sessions
                (id, plugin_id, project_root, project_name, detected_goal, outcome, started_at, ended_at, summary_text)
                VALUES (?, ?, ?, ?, NULL, ?, ?, NULL, NULL);
                """
            )
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_text(statement, 1, id.uuidString, -1, transientDestructor)
            sqlite3_bind_text(statement, 2, pluginID, -1, transientDestructor)
            sqlite3_bind_text(statement, 3, projectRoot, -1, transientDestructor)
            sqlite3_bind_text(statement, 4, projectName, -1, transientDestructor)
            sqlite3_bind_text(statement, 5, SessionOutcome.inProgress.rawValue, -1, transientDestructor)
            sqlite3_bind_double(statement, 6, startedAt.timeIntervalSince1970)
            if sqlite3_step(statement) != SQLITE_DONE {
                throw DatabaseError.step(message: String(cString: sqlite3_errmsg(dbPointer)))
            }
        }
    }

    func closeWorkflowSession(id: UUID, outcome: SessionOutcome, detectedGoal: String?, summaryText: String?, endedAt: Date) throws {
        try queue.sync {
            let statement = try prepare(
                """
                UPDATE workflow_sessions
                SET outcome = ?, detected_goal = ?, summary_text = ?, ended_at = ?
                WHERE id = ?;
                """
            )
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_text(statement, 1, outcome.rawValue, -1, transientDestructor)
            sqlite3_bind_text(statement, 2, detectedGoal, -1, transientDestructor)
            sqlite3_bind_text(statement, 3, summaryText, -1, transientDestructor)
            sqlite3_bind_double(statement, 4, endedAt.timeIntervalSince1970)
            sqlite3_bind_text(statement, 5, id.uuidString, -1, transientDestructor)
            if sqlite3_step(statement) != SQLITE_DONE {
                throw DatabaseError.step(message: String(cString: sqlite3_errmsg(dbPointer)))
            }
        }
    }

    func updateWorkflowSessionGoal(id: UUID, goal: String?) throws {
        try queue.sync {
            let statement = try prepare("UPDATE workflow_sessions SET detected_goal = ? WHERE id = ?;")
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_text(statement, 1, goal, -1, transientDestructor)
            sqlite3_bind_text(statement, 2, id.uuidString, -1, transientDestructor)
            if sqlite3_step(statement) != SQLITE_DONE {
                throw DatabaseError.step(message: String(cString: sqlite3_errmsg(dbPointer)))
            }
        }
    }

    func insertWorkflowCommand(_ command: WorkflowCommand) throws {
        try queue.sync {
            let statement = try prepare(
                """
                INSERT INTO workflow_commands
                (id, session_id, seq, command_text, cwd, exit_code, risk_level, started_at, ended_at, duration_ms)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                """
            )
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_text(statement, 1, command.id.uuidString, -1, transientDestructor)
            sqlite3_bind_text(statement, 2, command.sessionID.uuidString, -1, transientDestructor)
            sqlite3_bind_int(statement, 3, Int32(command.sequence))
            sqlite3_bind_text(statement, 4, command.commandText, -1, transientDestructor)
            sqlite3_bind_text(statement, 5, command.workingDirectory, -1, transientDestructor)
            if let exitCode = command.exitCode {
                sqlite3_bind_int(statement, 6, exitCode)
            } else {
                sqlite3_bind_null(statement, 6)
            }
            sqlite3_bind_text(statement, 7, command.riskLevel.rawValue, -1, transientDestructor)
            sqlite3_bind_double(statement, 8, command.startedAt.timeIntervalSince1970)
            if let endedAt = command.endedAt {
                sqlite3_bind_double(statement, 9, endedAt.timeIntervalSince1970)
            } else {
                sqlite3_bind_null(statement, 9)
            }
            if let duration = command.durationMilliseconds {
                sqlite3_bind_int(statement, 10, Int32(duration))
            } else {
                sqlite3_bind_null(statement, 10)
            }
            if sqlite3_step(statement) != SQLITE_DONE {
                throw DatabaseError.step(message: String(cString: sqlite3_errmsg(dbPointer)))
            }
        }
    }

    func updateWorkflowCommandCompletion(id: UUID, exitCode: Int32, endedAt: Date, durationMilliseconds: Int) throws {
        try queue.sync {
            let statement = try prepare(
                """
                UPDATE workflow_commands
                SET exit_code = ?, ended_at = ?, duration_ms = ?
                WHERE id = ?;
                """
            )
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_int(statement, 1, exitCode)
            sqlite3_bind_double(statement, 2, endedAt.timeIntervalSince1970)
            sqlite3_bind_int(statement, 3, Int32(durationMilliseconds))
            sqlite3_bind_text(statement, 4, id.uuidString, -1, transientDestructor)
            if sqlite3_step(statement) != SQLITE_DONE {
                throw DatabaseError.step(message: String(cString: sqlite3_errmsg(dbPointer)))
            }
        }
    }

    func nextWorkflowCommandSequence(sessionID: UUID) throws -> Int {
        try queue.sync {
            let statement = try prepare(
                "SELECT COALESCE(MAX(seq), 0) + 1 FROM workflow_commands WHERE session_id = ?;"
            )
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_text(statement, 1, sessionID.uuidString, -1, transientDestructor)
            if sqlite3_step(statement) == SQLITE_ROW {
                return Int(sqlite3_column_int(statement, 0))
            }
            return 1
        }
    }

    func insertWorkflowFileChanges(_ changes: [WorkflowFileChange]) throws {
        guard !changes.isEmpty else { return }
        try queue.sync {
            let statement = try prepare(
                """
                INSERT OR IGNORE INTO workflow_file_changes
                (id, session_id, command_id, path, change_kind, detected_at)
                VALUES (?, ?, ?, ?, ?, ?);
                """
            )
            defer { sqlite3_finalize(statement) }

            for change in changes {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)
                sqlite3_bind_text(statement, 1, change.id.uuidString, -1, transientDestructor)
                sqlite3_bind_text(statement, 2, change.sessionID.uuidString, -1, transientDestructor)
                if let commandID = change.commandID {
                    sqlite3_bind_text(statement, 3, commandID.uuidString, -1, transientDestructor)
                } else {
                    sqlite3_bind_null(statement, 3)
                }
                sqlite3_bind_text(statement, 4, change.path, -1, transientDestructor)
                sqlite3_bind_text(statement, 5, change.changeKind, -1, transientDestructor)
                sqlite3_bind_double(statement, 6, change.detectedAt.timeIntervalSince1970)
                if sqlite3_step(statement) != SQLITE_DONE {
                    throw DatabaseError.step(message: String(cString: sqlite3_errmsg(dbPointer)))
                }
            }
        }
    }

    func saveRollbackPlan(sessionID: UUID, planJSON: String, generatedAt: Date) throws {
        try queue.sync {
            let statement = try prepare(
                """
                INSERT INTO workflow_rollback_plans (id, session_id, plan_json, generated_at)
                VALUES (?, ?, ?, ?);
                """
            )
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_text(statement, 1, UUID().uuidString, -1, transientDestructor)
            sqlite3_bind_text(statement, 2, sessionID.uuidString, -1, transientDestructor)
            sqlite3_bind_text(statement, 3, planJSON, -1, transientDestructor)
            sqlite3_bind_double(statement, 4, generatedAt.timeIntervalSince1970)
            if sqlite3_step(statement) != SQLITE_DONE {
                throw DatabaseError.step(message: String(cString: sqlite3_errmsg(dbPointer)))
            }
        }
    }

    func loadWorkflowSession(id: UUID, pluginID: String) throws -> WorkflowSession? {
        try queue.sync {
            try loadWorkflowSessionUnlocked(id: id, pluginID: pluginID)
        }
    }

    func loadRecentWorkflowSessions(pluginID: String, limit: Int = 20) throws -> [WorkflowSession] {
        try queue.sync {
            let statement = try prepare(
                """
                SELECT id FROM workflow_sessions
                WHERE plugin_id = ?
                ORDER BY started_at DESC
                LIMIT ?;
                """
            )
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_text(statement, 1, pluginID, -1, transientDestructor)
            sqlite3_bind_int(statement, 2, Int32(limit))

            var sessions: [WorkflowSession] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0))) else {
                    continue
                }
                if let session = try loadWorkflowSessionUnlocked(id: id, pluginID: pluginID) {
                    sessions.append(session)
                }
            }
            return sessions
        }
    }

    func searchWorkflowSessions(pluginID: String, query: String, limit: Int = 20) throws -> [WorkflowSession] {
        let pattern = "%\(query)%"
        return try queue.sync {
            let statement = try prepare(
                """
                SELECT DISTINCT ws.id
                FROM workflow_sessions ws
                LEFT JOIN workflow_commands wc ON wc.session_id = ws.id
                WHERE ws.plugin_id = ?
                  AND (
                    ws.project_name LIKE ?
                    OR ws.detected_goal LIKE ?
                    OR wc.command_text LIKE ?
                  )
                ORDER BY ws.started_at DESC
                LIMIT ?;
                """
            )
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_text(statement, 1, pluginID, -1, transientDestructor)
            sqlite3_bind_text(statement, 2, pattern, -1, transientDestructor)
            sqlite3_bind_text(statement, 3, pattern, -1, transientDestructor)
            sqlite3_bind_text(statement, 4, pattern, -1, transientDestructor)
            sqlite3_bind_int(statement, 5, Int32(limit))

            var sessions: [WorkflowSession] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0))) else {
                    continue
                }
                if let session = try loadWorkflowSessionUnlocked(id: id, pluginID: pluginID) {
                    sessions.append(session)
                }
            }
            return sessions
        }
    }

    private func loadWorkflowSessionUnlocked(id: UUID, pluginID: String) throws -> WorkflowSession? {
        guard let session = try loadWorkflowSessionRow(id: id, pluginID: pluginID) else {
            return nil
        }
        let commands = try loadWorkflowCommands(sessionID: id)
        let fileChanges = try loadWorkflowFileChanges(sessionID: id)
        let rollbackPlan = try loadLatestRollbackPlan(sessionID: id)
        return WorkflowSession(
            id: session.id,
            pluginID: session.pluginID,
            projectRoot: session.projectRoot,
            projectName: session.projectName,
            detectedGoal: session.detectedGoal,
            outcome: session.outcome,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            summaryText: session.summaryText,
            commands: commands,
            fileChanges: fileChanges,
            rollbackPlanJSON: rollbackPlan
        )
    }

    private struct WorkflowSessionRow {
        var id: UUID
        var pluginID: String
        var projectRoot: String?
        var projectName: String?
        var detectedGoal: String?
        var outcome: SessionOutcome
        var startedAt: Date
        var endedAt: Date?
        var summaryText: String?
    }

    private func loadWorkflowSessionRow(id: UUID, pluginID: String) throws -> WorkflowSessionRow? {
        let statement = try prepare(
            """
            SELECT plugin_id, project_root, project_name, detected_goal, outcome, started_at, ended_at, summary_text
            FROM workflow_sessions
            WHERE id = ? AND plugin_id = ?;
            """
        )
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, id.uuidString, -1, transientDestructor)
        sqlite3_bind_text(statement, 2, pluginID, -1, transientDestructor)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }

        let outcomeRaw = String(cString: sqlite3_column_text(statement, 4))
        let endedAtValue = sqlite3_column_type(statement, 6) == SQLITE_NULL
            ? nil
            : Date(timeIntervalSince1970: sqlite3_column_double(statement, 6))
        let summaryValue = sqlite3_column_type(statement, 7) == SQLITE_NULL
            ? nil
            : String(cString: sqlite3_column_text(statement, 7))

        return WorkflowSessionRow(
            id: id,
            pluginID: String(cString: sqlite3_column_text(statement, 0)),
            projectRoot: optionalStringColumn(statement, index: 1),
            projectName: optionalStringColumn(statement, index: 2),
            detectedGoal: optionalStringColumn(statement, index: 3),
            outcome: SessionOutcome(rawValue: outcomeRaw) ?? .inProgress,
            startedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 5)),
            endedAt: endedAtValue,
            summaryText: summaryValue
        )
    }

    private func loadWorkflowCommands(sessionID: UUID) throws -> [WorkflowCommand] {
        let statement = try prepare(
            """
            SELECT id, seq, command_text, cwd, exit_code, risk_level, started_at, ended_at, duration_ms
            FROM workflow_commands
            WHERE session_id = ?
            ORDER BY seq;
            """
        )
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, sessionID.uuidString, -1, transientDestructor)

        var commands: [WorkflowCommand] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0))),
                let risk = CommandRiskLevel(rawValue: String(cString: sqlite3_column_text(statement, 5)))
            else {
                continue
            }

            let exitCode = sqlite3_column_type(statement, 4) == SQLITE_NULL
                ? nil
                : sqlite3_column_int(statement, 4)
            let endedAt = sqlite3_column_type(statement, 7) == SQLITE_NULL
                ? nil
                : Date(timeIntervalSince1970: sqlite3_column_double(statement, 7))
            let duration = sqlite3_column_type(statement, 8) == SQLITE_NULL
                ? nil
                : Int(sqlite3_column_int(statement, 8))

            commands.append(
                WorkflowCommand(
                    id: id,
                    sessionID: sessionID,
                    sequence: Int(sqlite3_column_int(statement, 1)),
                    commandText: String(cString: sqlite3_column_text(statement, 2)),
                    workingDirectory: optionalStringColumn(statement, index: 3),
                    exitCode: exitCode,
                    riskLevel: risk,
                    startedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 6)),
                    endedAt: endedAt,
                    durationMilliseconds: duration
                )
            )
        }
        return commands
    }

    private func loadWorkflowFileChanges(sessionID: UUID) throws -> [WorkflowFileChange] {
        let statement = try prepare(
            """
            SELECT id, command_id, path, change_kind, detected_at
            FROM workflow_file_changes
            WHERE session_id = ?
            ORDER BY detected_at;
            """
        )
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, sessionID.uuidString, -1, transientDestructor)

        var changes: [WorkflowFileChange] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0))) else {
                continue
            }
            let commandID = sqlite3_column_type(statement, 1) == SQLITE_NULL
                ? nil
                : UUID(uuidString: String(cString: sqlite3_column_text(statement, 1)))

            changes.append(
                WorkflowFileChange(
                    id: id,
                    sessionID: sessionID,
                    commandID: commandID,
                    path: String(cString: sqlite3_column_text(statement, 2)),
                    changeKind: String(cString: sqlite3_column_text(statement, 3)),
                    detectedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 4))
                )
            )
        }
        return changes
    }

    private func loadLatestRollbackPlan(sessionID: UUID) throws -> String? {
        let statement = try prepare(
            """
            SELECT plan_json FROM workflow_rollback_plans
            WHERE session_id = ?
            ORDER BY generated_at DESC
            LIMIT 1;
            """
        )
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, sessionID.uuidString, -1, transientDestructor)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return String(cString: sqlite3_column_text(statement, 0))
    }

    private func optionalStringColumn(_ statement: OpaquePointer?, index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return String(cString: sqlite3_column_text(statement, index))
    }

    static func minuteStart(for date: Date) -> Date {
        let seconds = floor(date.timeIntervalSince1970 / 60.0) * 60.0
        return Date(timeIntervalSince1970: seconds)
    }

    static func localDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    private func initializeSchema() throws {
        try queue.sync {
            try execute(
                """
                CREATE TABLE IF NOT EXISTS tracked_tools (
                    id TEXT PRIMARY KEY,
                    display_name TEXT NOT NULL,
                    match_type TEXT NOT NULL,
                    match_value TEXT NOT NULL,
                    color TEXT NOT NULL,
                    is_enabled INTEGER NOT NULL DEFAULT 1
                );
                """
            )

            try execute(
                """
                CREATE TABLE IF NOT EXISTS tool_minutes (
                    tool_id TEXT NOT NULL,
                    local_date TEXT NOT NULL,
                    minute_start REAL NOT NULL,
                    counted_open INTEGER NOT NULL DEFAULT 1,
                    PRIMARY KEY (tool_id, minute_start),
                    FOREIGN KEY (tool_id) REFERENCES tracked_tools(id)
                );
                """
            )

            try execute(
                """
                CREATE TABLE IF NOT EXISTS tool_runtime_state (
                    tool_id TEXT PRIMARY KEY,
                    is_running INTEGER NOT NULL DEFAULT 0,
                    current_run_minutes INTEGER NOT NULL DEFAULT 0,
                    last_seen_at REAL NOT NULL DEFAULT 0,
                    FOREIGN KEY (tool_id) REFERENCES tracked_tools(id)
                );
                """
            )

            try execute(
                """
                CREATE TABLE IF NOT EXISTS workflow_sessions (
                    id TEXT PRIMARY KEY,
                    plugin_id TEXT NOT NULL,
                    project_root TEXT,
                    project_name TEXT,
                    detected_goal TEXT,
                    outcome TEXT NOT NULL,
                    started_at REAL NOT NULL,
                    ended_at REAL,
                    summary_text TEXT
                );
                """
            )

            try execute(
                """
                CREATE TABLE IF NOT EXISTS workflow_commands (
                    id TEXT PRIMARY KEY,
                    session_id TEXT NOT NULL,
                    seq INTEGER NOT NULL,
                    command_text TEXT NOT NULL,
                    cwd TEXT,
                    exit_code INTEGER,
                    risk_level TEXT NOT NULL,
                    started_at REAL NOT NULL,
                    ended_at REAL,
                    duration_ms INTEGER,
                    FOREIGN KEY (session_id) REFERENCES workflow_sessions(id)
                );
                """
            )

            try execute(
                """
                CREATE TABLE IF NOT EXISTS workflow_file_changes (
                    id TEXT PRIMARY KEY,
                    session_id TEXT NOT NULL,
                    command_id TEXT,
                    path TEXT NOT NULL,
                    change_kind TEXT NOT NULL,
                    detected_at REAL NOT NULL,
                    FOREIGN KEY (session_id) REFERENCES workflow_sessions(id),
                    FOREIGN KEY (command_id) REFERENCES workflow_commands(id)
                );
                """
            )

            try execute(
                """
                CREATE TABLE IF NOT EXISTS workflow_rollback_plans (
                    id TEXT PRIMARY KEY,
                    session_id TEXT NOT NULL,
                    plan_json TEXT NOT NULL,
                    generated_at REAL NOT NULL,
                    FOREIGN KEY (session_id) REFERENCES workflow_sessions(id)
                );
                """
            )
        }
    }

    private func countRows(table: String) throws -> Int {
        let statement = try prepare("SELECT COUNT(*) FROM \(table);")
        defer { sqlite3_finalize(statement) }
        if sqlite3_step(statement) == SQLITE_ROW {
            return Int(sqlite3_column_int(statement, 0))
        }
        return 0
    }

    private func execute(_ sql: String) throws {
        if sqlite3_exec(dbPointer, sql, nil, nil, nil) != SQLITE_OK {
            throw DatabaseError.step(message: String(cString: sqlite3_errmsg(dbPointer)))
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(dbPointer, sql, -1, &statement, nil) != SQLITE_OK {
            throw DatabaseError.prepare(message: String(cString: sqlite3_errmsg(dbPointer)))
        }
        return statement
    }
}

private let transientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum DatabaseError: LocalizedError {
    case open(message: String)
    case prepare(message: String)
    case step(message: String)

    var errorDescription: String? {
        switch self {
        case .open(let message), .prepare(let message), .step(let message):
            return message
        }
    }
}
