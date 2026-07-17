import Foundation
import Observation

@MainActor
@Observable
final class TerminalSessionManager {
    private(set) var sessions: [TerminalSession]
    private(set) var selectedSessionID: UUID

    var selectedSession: TerminalSession? {
        sessions.first(where: { $0.id == selectedSessionID })
    }

    init(startupWorkingDirectory: String?) {
        let initial = TerminalSession.make(startupWorkingDirectory: startupWorkingDirectory)
        sessions = [initial]
        selectedSessionID = initial.id
    }

    @discardableResult
    func createTab(startupWorkingDirectory: String?) -> UUID {
        let session = TerminalSession.make(startupWorkingDirectory: startupWorkingDirectory)
        sessions.append(session)
        selectedSessionID = session.id
        return session.id
    }

    func select(_ id: UUID) {
        guard sessions.contains(where: { $0.id == id }) else { return }
        selectedSessionID = id
    }

    /// Removes the tab. Returns `true` when the last tab was closed and the window should close.
    @discardableResult
    func closeTab(_ id: UUID) -> Bool {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else {
            return sessions.isEmpty
        }

        sessions.remove(at: index)

        if sessions.isEmpty {
            return true
        }

        if selectedSessionID == id {
            let nextIndex = min(index, sessions.count - 1)
            selectedSessionID = sessions[nextIndex].id
        }

        return false
    }

    /// Closes the selected tab. Returns `true` when the window should close.
    @discardableResult
    func closeSelectedTab() -> Bool {
        closeTab(selectedSessionID)
    }

    func focusPane(tabID: UUID, paneID: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == tabID }) else { return }
        guard sessions[index].pane(id: paneID) != nil else { return }
        sessions[index].focusedPaneID = paneID
        selectedSessionID = tabID
    }

    /// Splits `paneID` along `axis`, creating a new pane. Returns the new pane id, or `nil` if capped.
    @discardableResult
    func splitPane(
        tabID: UUID,
        paneID: UUID,
        axis: SplitAxis,
        startupWorkingDirectory: String?
    ) -> UUID? {
        guard let index = sessions.firstIndex(where: { $0.id == tabID }) else { return nil }
        var session = sessions[index]
        guard session.canSplit, session.pane(id: paneID) != nil else { return nil }

        let newPane = TerminalPane.make(startupWorkingDirectory: startupWorkingDirectory)
        let replacement = PaneLayout.split(
            axis: axis,
            first: .leaf(paneID),
            second: .leaf(newPane.id)
        )
        guard let newLayout = session.layout.replacingLeaf(paneID, with: replacement) else {
            return nil
        }

        session.panes.append(newPane)
        session.layout = newLayout
        session.focusedPaneID = newPane.id
        sessions[index] = session
        selectedSessionID = tabID
        return newPane.id
    }

    /// Closes a pane. Returns `true` when the tab (and possibly window) should close.
    @discardableResult
    func closePane(tabID: UUID, paneID: UUID) -> Bool {
        guard let index = sessions.firstIndex(where: { $0.id == tabID }) else {
            return sessions.isEmpty
        }

        var session = sessions[index]
        guard session.pane(id: paneID) != nil else {
            return false
        }

        if session.panes.count <= 1 {
            return closeTab(tabID)
        }

        guard let newLayout = session.layout.removingPane(paneID) else {
            return closeTab(tabID)
        }

        session.panes.removeAll { $0.id == paneID }
        session.layout = newLayout
        if session.focusedPaneID == paneID {
            session.focusedPaneID = newLayout.paneIDs.first ?? session.panes[0].id
        }
        sessions[index] = session
        return false
    }

    func updateSession(_ id: UUID, update: (inout TerminalSession) -> Void) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        update(&sessions[index])
    }

    func updatePane(tabID: UUID, paneID: UUID, update: (inout TerminalPane) -> Void) {
        guard let tabIndex = sessions.firstIndex(where: { $0.id == tabID }) else { return }
        guard let paneIndex = sessions[tabIndex].panes.firstIndex(where: { $0.id == paneID }) else {
            return
        }
        update(&sessions[tabIndex].panes[paneIndex])
    }
}
