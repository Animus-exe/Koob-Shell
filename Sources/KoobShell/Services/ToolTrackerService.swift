import AppKit
import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class ToolTrackerService {
    private static let logger = Logger(subsystem: "com.vurzumm.koobshell", category: "ToolTracker")

    private let database: ActivityDatabase
    private var workspaceObservers: [NSObjectProtocol] = []
    private var refreshTimer: Timer?
    private var pendingWorkspaceRefresh: DispatchWorkItem?
    private(set) var trackedTools: [TrackedTool] = []
    private(set) var summaries: [ToolUsageSummary] = []
    private(set) var runningToolIDs: Set<UUID> = []
    private var lastRecordedMinute: Date?

    init(database: ActivityDatabase) {
        self.database = database
    }

    func start() {
        do {
            try database.seedTrackedToolsIfNeeded(TrackedTool.seeded)
            trackedTools = try database.loadTrackedTools()
            refreshRunningApplications()
            refreshSummaries()
        } catch {
            Self.logger.error("Tracker start failed: \(error.localizedDescription, privacy: .public)")
        }

        let workspace = NSWorkspace.shared.notificationCenter
        workspaceObservers = [
            workspace.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.scheduleWorkspaceRefresh()
                }
            },
            workspace.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.scheduleWorkspaceRefresh()
                }
            },
        ]

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshRunningApplications()
            }
        }
    }

    func stop() {
        pendingWorkspaceRefresh?.cancel()
        pendingWorkspaceRefresh = nil
        refreshTimer?.invalidate()
        refreshTimer = nil
        workspaceObservers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        workspaceObservers.removeAll()
    }

    func setToolEnabled(_ tool: TrackedTool, isEnabled: Bool) {
        do {
            try database.setTrackedToolEnabled(id: tool.id, isEnabled: isEnabled)
            reloadTools()
            refreshRunningApplications()
        } catch {
            Self.logger.error("Enable tool failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    @discardableResult
    func setToolEnabled(named query: String, isEnabled: Bool) throws -> TrackedTool {
        let matches = try database.findTrackedTools(matching: query)
        guard let tool = matches.first else {
            throw TrackerCommandError.notFound(query)
        }
        guard matches.count == 1 else {
            throw TrackerCommandError.ambiguous(query, matches.map(\.displayName))
        }
        try database.setTrackedToolEnabled(id: tool.id, isEnabled: isEnabled)
        reloadTools()
        refreshRunningApplications()
        return tool
    }

    @discardableResult
    func addTool(
        displayName: String,
        matchType: ToolMatchType,
        matchValue: String,
        color: String? = nil
    ) throws -> TrackedTool {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = matchValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !value.isEmpty else {
            throw TrackerCommandError.invalidArguments
        }

        let existing = try database.loadTrackedTools()
        if existing.contains(where: {
            $0.displayName.caseInsensitiveCompare(name) == .orderedSame
                || ($0.matchType == matchType && $0.matchValue.caseInsensitiveCompare(value) == .orderedSame)
        }) {
            throw TrackerCommandError.alreadyExists(name)
        }

        let tool = TrackedTool(
            displayName: name,
            matchType: matchType,
            matchValue: value,
            color: color ?? TrackedToolMatcher.color(for: name),
            isEnabled: true
        )
        try database.insertTrackedTool(tool)
        reloadTools()
        refreshRunningApplications()
        return tool
    }

    @discardableResult
    func removeTool(named query: String) throws -> TrackedTool {
        let matches = try database.findTrackedTools(matching: query)
        guard let tool = matches.first else {
            throw TrackerCommandError.notFound(query)
        }
        guard matches.count == 1 else {
            throw TrackerCommandError.ambiguous(query, matches.map(\.displayName))
        }
        try database.deleteTrackedTool(id: tool.id)
        reloadTools()
        refreshRunningApplications()
        return tool
    }

    func refreshRunningApplications(date: Date = Date()) {
        let apps = NSWorkspace.shared.runningApplications
        let appBundleIDs = Set(apps.compactMap(\.bundleIdentifier))
        let appLocalizedNames = Set(apps.compactMap { $0.localizedName?.lowercased() })
        let appExecutableNames = Set(
            apps.compactMap { $0.executableURL?.lastPathComponent.lowercased() }
        )

        // Avoid forking `/bin/ps` unless an enabled tool actually needs process-name matching.
        let needsProcessSnapshot = trackedTools.contains {
            $0.isEnabled && $0.matchType == .executableName
        }
        let processNames = needsProcessSnapshot ? ProcessSnapshot.runningExecutableNames() : []

        let active = Set(
            trackedTools
                .filter(\.isEnabled)
                .filter { tool in
                    TrackedToolMatcher.isRunning(
                        matchType: tool.matchType,
                        matchValue: tool.matchValue,
                        appBundleIDs: appBundleIDs,
                        appLocalizedNames: appLocalizedNames,
                        appExecutableNames: appExecutableNames,
                        processNames: processNames
                    )
                }
                .map(\.id)
        )

        runningToolIDs = active
        recordIfNeeded(for: date)
        syncRuntimeState(for: date)
        refreshSummaries(date: date)
    }

    func refreshSummaries(date: Date = Date()) {
        do {
            summaries = try database.loadUsageSummaries(runningToolIDs: runningToolIDs, now: date)
        } catch {
            Self.logger.error("Summary refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func scheduleWorkspaceRefresh() {
        pendingWorkspaceRefresh?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.refreshRunningApplications()
        }
        pendingWorkspaceRefresh = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    private func reloadTools() {
        do {
            trackedTools = try database.loadTrackedTools()
        } catch {
            Self.logger.error("Reload tools failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func recordIfNeeded(for date: Date) {
        let minuteStart = ActivityDatabase.minuteStart(for: date)
        guard lastRecordedMinute != minuteStart else { return }
        lastRecordedMinute = minuteStart

        do {
            try database.recordMinute(for: runningToolIDs, at: date)
        } catch {
            Self.logger.error("Minute record failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func syncRuntimeState(for date: Date) {
        do {
            let currentRunMinutes = try database.loadCurrentRunMinutes(for: runningToolIDs, now: date)
            try database.updateRuntimeState(
                for: trackedTools,
                runningToolIDs: runningToolIDs,
                currentRunMinutes: currentRunMinutes,
                observedAt: date
            )
        } catch {
            Self.logger.error("Runtime state sync failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

enum TrackerCommandError: LocalizedError, Equatable {
    case invalidArguments
    case notFound(String)
    case alreadyExists(String)
    case ambiguous(String, [String])

    var errorDescription: String? {
        switch self {
        case .invalidArguments:
            return "Display name and match value are required."
        case .notFound(let query):
            return "No tracked process matches '\(query)'."
        case .alreadyExists(let name):
            return "'\(name)' is already tracked."
        case .ambiguous(let query, let names):
            return "Multiple matches for '\(query)': \(names.joined(separator: ", "))."
        }
    }
}
