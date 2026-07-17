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

    func updateSession(_ id: UUID, update: (inout TerminalSession) -> Void) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        update(&sessions[index])
    }
}
