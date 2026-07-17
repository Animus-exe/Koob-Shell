import Foundation
import Observation

@MainActor
@Observable
final class WorkflowSessionService {
    private let database: ActivityDatabase
    private let workflowRuntime: WorkflowPluginRuntime

    private(set) var activeSession: WorkflowSession?
    private(set) var recentSessions: [WorkflowSession] = []
    private(set) var selectedSession: WorkflowSession?
    private(set) var lastError: String?

    private var openWorkflowSessionIDs: Set<String> = []

    init(database: ActivityDatabase, workflowRuntime: WorkflowPluginRuntime) {
        self.database = database
        self.workflowRuntime = workflowRuntime
    }

    func refreshRecentSessions() {
        guard workflowRuntime.isActive, let pluginID = workflowRuntime.activePluginID else {
            recentSessions = []
            return
        }

        do {
            recentSessions = try database.loadRecentWorkflowSessions(pluginID: pluginID, limit: 20)
            if selectedSession == nil {
                selectedSession = recentSessions.first
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func openTerminalSession(sessionID: String, workingDirectory: String?) {
        guard workflowRuntime.isActive,
              workflowRuntime.settings.captureEnabled,
              let pluginID = workflowRuntime.activePluginID else {
            return
        }

        guard !openWorkflowSessionIDs.contains(sessionID) else {
            focusTerminalSession(sessionID: sessionID)
            return
        }

        let cwd = workingDirectory ?? NSHomeDirectory()
        let context = ProjectContextResolver.resolve(workingDirectory: cwd)
        guard let uuid = UUID(uuidString: sessionID) else { return }

        do {
            try database.openWorkflowSession(
                id: uuid,
                pluginID: pluginID,
                projectRoot: context.root,
                projectName: context.name,
                startedAt: Date()
            )
            openWorkflowSessionIDs.insert(sessionID)
            activeSession = try database.loadWorkflowSession(id: uuid, pluginID: pluginID)
            selectedSession = activeSession
            invokeKoobshell(arguments: ["session-open"], sessionID: sessionID)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func closeTerminalSession(sessionID: String) {
        guard openWorkflowSessionIDs.contains(sessionID) else { return }
        guard workflowRuntime.isActive,
              let pluginID = workflowRuntime.activePluginID,
              let uuid = UUID(uuidString: sessionID) else {
            openWorkflowSessionIDs.remove(sessionID)
            return
        }

        openWorkflowSessionIDs.remove(sessionID)

        do {
            if var session = try database.loadWorkflowSession(id: uuid, pluginID: pluginID) {
                let goal = SessionGoalDetector.detectGoal(from: session.commands, rules: workflowRuntime.rules.goals)
                let outcome = resolveOutcome(for: session.commands)
                let rollbackPlan = RollbackPlanGenerator.generate(session: session, rules: workflowRuntime.rules.rollback)
                try database.saveRollbackPlan(sessionID: uuid, planJSON: rollbackPlan, generatedAt: Date())

                var summary: String?
                if workflowRuntime.settings.autoSummaryOnExit {
                    session.detectedGoal = goal
                    session.outcome = outcome
                    session.rollbackPlanJSON = rollbackPlan
                    summary = WorkflowReportGenerator.generate(session: session, rollbackPlan: rollbackPlan)
                }

                try database.closeWorkflowSession(
                    id: uuid,
                    outcome: outcome,
                    detectedGoal: goal,
                    summaryText: summary,
                    endedAt: Date()
                )
            }

            invokeKoobshell(arguments: ["session-close", sessionID], sessionID: sessionID)

            if activeSession?.id == uuid {
                activeSession = nil
            }
            if selectedSession?.id == uuid {
                selectedSession = recentSessions.first { $0.id != uuid }
            }

            refreshRecentSessions()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func focusTerminalSession(sessionID: String) {
        guard workflowRuntime.isActive,
              let pluginID = workflowRuntime.activePluginID,
              let uuid = UUID(uuidString: sessionID) else {
            return
        }

        do {
            if openWorkflowSessionIDs.contains(sessionID),
               let session = try database.loadWorkflowSession(id: uuid, pluginID: pluginID) {
                activeSession = session
                selectedSession = session
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func selectSession(_ session: WorkflowSession?) {
        selectedSession = session
    }

    func searchSessions(query: String) {
        guard workflowRuntime.isActive, let pluginID = workflowRuntime.activePluginID else {
            return
        }

        do {
            recentSessions = try database.searchWorkflowSessions(pluginID: pluginID, query: query, limit: 20)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func report(for session: WorkflowSession, format: WorkflowReportGenerator.Format = .text) -> String {
        let rollback = session.rollbackPlanJSON
            ?? RollbackPlanGenerator.generate(session: session, rules: workflowRuntime.rules.rollback)
        return WorkflowReportGenerator.generate(session: session, rollbackPlan: rollback, format: format)
    }

    func rollbackPlan(for session: WorkflowSession) -> String {
        session.rollbackPlanJSON
            ?? RollbackPlanGenerator.generate(session: session, rules: workflowRuntime.rules.rollback)
    }

    private func resolveOutcome(for commands: [WorkflowCommand]) -> SessionOutcome {
        let failures = commands.filter { ($0.exitCode ?? 0) != 0 }.count
        let successes = commands.filter { ($0.exitCode ?? 0) == 0 }.count

        if failures == 0, successes > 0 {
            return .success
        }
        if successes == 0, failures > 0 {
            return .failure
        }
        if failures == 0, successes == 0 {
            return .inProgress
        }
        return .mixed
    }

    private func invokeKoobshell(arguments: [String], sessionID: String) {
        guard FileManager.default.fileExists(atPath: AppPaths.koobshellCommandURL.path) else { return }

        let process = Process()
        process.executableURL = AppPaths.koobshellCommandURL
        process.arguments = arguments

        var environment = ProcessInfo.processInfo.environment
        environment["KOOBSHELL_SESSION_ID"] = sessionID
        if let pluginID = workflowRuntime.activePluginID {
            environment["KOOBSHELL_PLUGIN_ID"] = pluginID
        }
        process.environment = environment

        do {
            try process.run()
        } catch {
            lastError = error.localizedDescription
        }
    }
}
