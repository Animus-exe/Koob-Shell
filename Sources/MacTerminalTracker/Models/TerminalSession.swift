import Foundation

struct TerminalSession: Identifiable, Equatable, Sendable {
    let id: UUID
    let workflowSessionID: String
    var title: String
    var currentWorkingDirectory: String?
    var shellIsRunning: Bool
    var hasStarted: Bool

    init(
        id: UUID = UUID(),
        workflowSessionID: String = UUID().uuidString,
        title: String = AppPaths.displayName,
        currentWorkingDirectory: String? = nil,
        shellIsRunning: Bool = false,
        hasStarted: Bool = false
    ) {
        self.id = id
        self.workflowSessionID = workflowSessionID
        self.title = title
        self.currentWorkingDirectory = currentWorkingDirectory
        self.shellIsRunning = shellIsRunning
        self.hasStarted = hasStarted
    }

    var tabLabel: String {
        if let currentWorkingDirectory, !currentWorkingDirectory.isEmpty {
            let name = URL(fileURLWithPath: currentWorkingDirectory).lastPathComponent
            if !name.isEmpty {
                return name
            }
        }

        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? AppPaths.displayName : trimmed
    }

    static func make(startupWorkingDirectory: String?) -> TerminalSession {
        TerminalSession(
            title: AppPaths.displayName,
            currentWorkingDirectory: startupWorkingDirectory
        )
    }
}
