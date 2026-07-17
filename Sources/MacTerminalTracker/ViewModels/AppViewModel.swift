import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AppViewModel {
    var appearanceStore: AppearanceStore
    var commandStore: CommandStore
    var pluginStore: PluginStore
    var commandRegistry: CommandRegistry
    var themeRegistry: ThemeRegistry
    var galleryRegistry: GalleryRegistry
    var tracker: ToolTrackerService
    let database: ActivityDatabase
    let workflowRuntime: WorkflowPluginRuntime
    let workflowSessions: WorkflowSessionService
    let sessions: TerminalSessionManager
    var openPreferencesHandler: (@MainActor @Sendable () -> Void)?

    var statusMessage = "Ready"
    var lastTerminalActivityAt = Date()
    let startupWorkingDirectory: String
    var showWorkflowInspector = true
    var focusToken = 0

    var activeTheme: ThemeDefinition {
        themeRegistry.activeTheme
    }

    var activeBorder: ShellBorderStyle {
        themeRegistry.activeBorder
    }

    var activeTitleBar: ShellBorderStyle {
        themeRegistry.activeTitleBar
    }

    var availableThemes: [ThemeCatalogItem] {
        themeRegistry.catalog
    }

    var availableGalleries: [GalleryCatalogItem] {
        galleryRegistry.catalog
    }

    var terminalTitle: String {
        sessions.selectedSession?.title ?? AppPaths.displayName
    }

    var currentWorkingDirectory: String? {
        sessions.selectedSession?.currentWorkingDirectory
    }

    var shellIsRunning: Bool {
        sessions.selectedSession?.shellIsRunning ?? false
    }

    init(
        appearanceStore: AppearanceStore,
        commandStore: CommandStore,
        pluginStore: PluginStore,
        commandRegistry: CommandRegistry,
        themeRegistry: ThemeRegistry,
        galleryRegistry: GalleryRegistry,
        tracker: ToolTrackerService,
        database: ActivityDatabase,
        workflowRuntime: WorkflowPluginRuntime,
        workflowSessions: WorkflowSessionService,
        startupWorkingDirectory: String = ShellStartupContextResolver.resolve()
    ) {
        self.appearanceStore = appearanceStore
        self.commandStore = commandStore
        self.pluginStore = pluginStore
        self.commandRegistry = commandRegistry
        self.themeRegistry = themeRegistry
        self.galleryRegistry = galleryRegistry
        self.tracker = tracker
        self.database = database
        self.workflowRuntime = workflowRuntime
        self.workflowSessions = workflowSessions
        self.startupWorkingDirectory = startupWorkingDirectory
        self.sessions = TerminalSessionManager(startupWorkingDirectory: startupWorkingDirectory)

        appearanceStore.onChange = { [weak self] in
            guard let self else { return }
            self.themeRegistry.refresh()
            self.galleryRegistry.refresh()
        }
    }

    func start() {
        do {
            try TrackerCommandInstaller.install()
        } catch {
            statusMessage = "Tracker command install error: \(error.localizedDescription)"
        }

        pluginStore.reload()
        workflowRuntime.refresh(using: pluginStore)
        commandRegistry.refresh()
        themeRegistry.refresh()
        galleryRegistry.refresh()
        workflowSessions.refreshRecentSessions()
        tracker.start()
        if workflowRuntime.isActive {
            statusMessage = "Terminal ready — Workflow Intelligence active"
        } else {
            statusMessage = "Terminal ready"
        }
    }

    func stop() {
        for session in sessions.sessions {
            workflowSessions.closeTerminalSession(sessionID: session.workflowSessionID)
        }
        tracker.stop()
    }

    func noteTerminalActivity() {
        lastTerminalActivityAt = Date()
    }

    func newTab() {
        sessions.createTab(startupWorkingDirectory: currentWorkingDirectory ?? startupWorkingDirectory)
        requestTerminalFocus()
        statusMessage = "New tab"
    }

    /// Returns `true` when the window should close (last tab closed).
    @discardableResult
    func closeSelectedTab() -> Bool {
        guard let session = sessions.selectedSession else { return true }
        return closeTab(session.id)
    }

    /// Returns `true` when the window should close (last tab closed).
    @discardableResult
    func closeTab(_ id: UUID) -> Bool {
        guard let session = sessions.sessions.first(where: { $0.id == id }) else {
            return sessions.sessions.isEmpty
        }

        workflowSessions.closeTerminalSession(sessionID: session.workflowSessionID)
        let shouldCloseWindow = sessions.closeTab(id)

        if !shouldCloseWindow {
            if let selected = sessions.selectedSession {
                workflowSessions.focusTerminalSession(sessionID: selected.workflowSessionID)
            }
            requestTerminalFocus()
            statusMessage = "Tab closed"
        }

        return shouldCloseWindow
    }

    func selectTab(_ id: UUID) {
        sessions.select(id)
        if let session = sessions.selectedSession {
            workflowSessions.focusTerminalSession(sessionID: session.workflowSessionID)
        }
        requestTerminalFocus()
    }

    func handleTerminalReady(sessionID: UUID) {
        guard let session = sessions.sessions.first(where: { $0.id == sessionID }) else { return }

        sessions.updateSession(sessionID) { session in
            session.shellIsRunning = true
            session.hasStarted = true
        }
        lastTerminalActivityAt = Date()
        workflowSessions.openTerminalSession(
            sessionID: session.workflowSessionID,
            workingDirectory: session.currentWorkingDirectory ?? startupWorkingDirectory
        )
        workflowSessions.refreshRecentSessions()
        if workflowRuntime.isActive {
            statusMessage = "Shell session started — capturing workflow"
        } else {
            statusMessage = "Shell session started"
        }
        if sessions.selectedSessionID == sessionID {
            requestTerminalFocus()
        }
    }

    func handleTerminalExit(sessionID: UUID, exitCode: Int32?) {
        guard let session = sessions.sessions.first(where: { $0.id == sessionID }) else { return }

        workflowSessions.closeTerminalSession(sessionID: session.workflowSessionID)
        sessions.updateSession(sessionID) { session in
            session.shellIsRunning = false
        }
        lastTerminalActivityAt = Date()
        if let exitCode {
            statusMessage = "Shell exited with status \(exitCode)"
        } else {
            statusMessage = "Shell session ended"
        }
    }

    func handleTerminalLaunchFailure(sessionID: UUID, reason: String) {
        sessions.updateSession(sessionID) { session in
            session.shellIsRunning = false
            session.hasStarted = true
        }
        statusMessage = reason
    }

    func updateTerminalTitle(sessionID: UUID, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        sessions.updateSession(sessionID) { session in
            session.title = trimmed.isEmpty ? AppPaths.displayName : trimmed
        }
    }

    func updateWorkingDirectory(sessionID: UUID, directory: String?) {
        sessions.updateSession(sessionID) { session in
            session.currentWorkingDirectory = directory
        }
    }

    func reloadPlugins() {
        pluginStore.reload()
        workflowRuntime.refresh(using: pluginStore)
        commandRegistry.refresh()
        themeRegistry.refresh()
        galleryRegistry.refresh()
        workflowSessions.refreshRecentSessions()
    }

    func updateWorkflowSettings(_ settings: WorkflowPluginSettings) {
        do {
            try workflowRuntime.updateSettings(settings)
        } catch {
            statusMessage = "Workflow settings error: \(error.localizedDescription)"
        }
    }

    func openPreferencesWindow() {
        if let openPreferencesHandler {
            openPreferencesHandler()
            return
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    func requestTerminalFocus() {
        focusToken += 1
    }
}
