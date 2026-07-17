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
        statusMessage = "Terminal ready"
    }

    func stop() {
        for session in sessions.sessions {
            for pane in session.panes {
                workflowSessions.closeTerminalSession(sessionID: pane.workflowSessionID)
                TerminalHostRegistry.remove(paneID: pane.id)
            }
        }
        tracker.stop()
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

        for pane in session.panes {
            workflowSessions.closeTerminalSession(sessionID: pane.workflowSessionID)
            TerminalHostRegistry.remove(paneID: pane.id)
        }
        let shouldCloseWindow = sessions.closeTab(id)

        if !shouldCloseWindow {
            if let selected = sessions.selectedSession,
               let focused = selected.focusedPane {
                workflowSessions.focusTerminalSession(sessionID: focused.workflowSessionID)
            }
            requestTerminalFocus()
            statusMessage = "Tab closed"
        }

        return shouldCloseWindow
    }

    func selectTab(_ id: UUID) {
        sessions.select(id)
        if let session = sessions.selectedSession,
           let focused = session.focusedPane {
            workflowSessions.focusTerminalSession(sessionID: focused.workflowSessionID)
        }
        requestTerminalFocus()
    }

    func focusPane(tabID: UUID, paneID: UUID) {
        let alreadyFocused = sessions.selectedSessionID == tabID
            && sessions.selectedSession?.focusedPaneID == paneID
        sessions.focusPane(tabID: tabID, paneID: paneID)
        if let pane = sessions.sessions.first(where: { $0.id == tabID })?.pane(id: paneID) {
            workflowSessions.focusTerminalSession(sessionID: pane.workflowSessionID)
        }
        if !alreadyFocused {
            requestTerminalFocus()
        }
    }

    @discardableResult
    func splitPane(tabID: UUID, paneID: UUID, axis: SplitAxis) -> Bool {
        guard let source = sessions.sessions.first(where: { $0.id == tabID })?.pane(id: paneID) else {
            return false
        }
        let directory = source.currentWorkingDirectory ?? startupWorkingDirectory
        guard sessions.splitPane(
            tabID: tabID,
            paneID: paneID,
            axis: axis,
            startupWorkingDirectory: directory
        ) != nil else {
            statusMessage = "Maximum of \(TerminalSession.maxPanes) panes per tab"
            return false
        }
        requestTerminalFocus()
        statusMessage = axis == .horizontal ? "Split vertically" : "Split horizontally"
        return true
    }

    /// Returns `true` when the window should close.
    @discardableResult
    func closePane(tabID: UUID, paneID: UUID) -> Bool {
        guard let session = sessions.sessions.first(where: { $0.id == tabID }),
              let pane = session.pane(id: paneID) else {
            return false
        }

        workflowSessions.closeTerminalSession(sessionID: pane.workflowSessionID)
        TerminalHostRegistry.remove(paneID: pane.id)
        let closingLastPaneInTab = session.panes.count <= 1
        let shouldCloseWindow = sessions.closePane(tabID: tabID, paneID: paneID)

        if !shouldCloseWindow {
            if let selected = sessions.selectedSession,
               let focused = selected.focusedPane {
                workflowSessions.focusTerminalSession(sessionID: focused.workflowSessionID)
            }
            requestTerminalFocus()
            statusMessage = closingLastPaneInTab ? "Tab closed" : "Pane closed"
        }

        return shouldCloseWindow
    }

    func handleTerminalReady(tabID: UUID, paneID: UUID) {
        guard let pane = sessions.sessions.first(where: { $0.id == tabID })?.pane(id: paneID) else {
            return
        }

        sessions.updatePane(tabID: tabID, paneID: paneID) { pane in
            pane.shellIsRunning = true
            pane.hasStarted = true
        }
        lastTerminalActivityAt = Date()
        workflowSessions.openTerminalSession(
            sessionID: pane.workflowSessionID,
            workingDirectory: pane.currentWorkingDirectory ?? startupWorkingDirectory
        )
        statusMessage = "Shell session started"
        if sessions.selectedSessionID == tabID,
           sessions.selectedSession?.focusedPaneID == paneID {
            requestTerminalFocus()
        }
    }

    func handleTerminalExit(tabID: UUID, paneID: UUID, exitCode: Int32?) {
        guard sessions.sessions.first(where: { $0.id == tabID })?.pane(id: paneID) != nil else {
            return
        }

        if let pane = sessions.sessions.first(where: { $0.id == tabID })?.pane(id: paneID) {
            workflowSessions.closeTerminalSession(sessionID: pane.workflowSessionID)
        }
        sessions.updatePane(tabID: tabID, paneID: paneID) { pane in
            pane.shellIsRunning = false
        }
        lastTerminalActivityAt = Date()
        if let exitCode {
            statusMessage = "Shell exited with status \(exitCode)"
        } else {
            statusMessage = "Shell session ended"
        }
    }

    func handleTerminalLaunchFailure(tabID: UUID, paneID: UUID, reason: String) {
        sessions.updatePane(tabID: tabID, paneID: paneID) { pane in
            pane.shellIsRunning = false
            pane.hasStarted = true
        }
        statusMessage = reason
    }

    func updateTerminalTitle(tabID: UUID, paneID: UUID, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = trimmed.isEmpty ? AppPaths.displayName : trimmed
        guard let pane = sessions.sessions.first(where: { $0.id == tabID })?.pane(id: paneID),
              pane.title != resolved
        else {
            return
        }

        sessions.updatePane(tabID: tabID, paneID: paneID) { pane in
            pane.title = resolved
        }
    }

    func updateWorkingDirectory(tabID: UUID, paneID: UUID, directory: String?) {
        guard let pane = sessions.sessions.first(where: { $0.id == tabID })?.pane(id: paneID),
              pane.currentWorkingDirectory != directory
        else {
            return
        }

        sessions.updatePane(tabID: tabID, paneID: paneID) { pane in
            pane.currentWorkingDirectory = directory
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

    func setPluginEnabled(pluginID: String, isEnabled: Bool) {
        do {
            try pluginStore.setEnabled(pluginID: pluginID, isEnabled: isEnabled)
            workflowRuntime.refresh(using: pluginStore)
            commandRegistry.refresh()
            themeRegistry.refresh()
            galleryRegistry.refresh()
            workflowSessions.refreshRecentSessions()
            statusMessage = isEnabled ? "Plugin enabled" : "Plugin disabled"
        } catch {
            statusMessage = "Plugin toggle error: \(error.localizedDescription)"
        }
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
