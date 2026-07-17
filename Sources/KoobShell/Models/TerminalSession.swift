import Foundation

enum SplitAxis: String, Hashable, Sendable {
    /// Side-by-side panes (vertical divider).
    case horizontal
    /// Stacked panes (horizontal divider).
    case vertical
}

indirect enum PaneLayout: Hashable, Sendable {
    case leaf(UUID)
    case split(axis: SplitAxis, first: PaneLayout, second: PaneLayout)

    var paneIDs: [UUID] {
        switch self {
        case .leaf(let id):
            return [id]
        case .split(_, let first, let second):
            return first.paneIDs + second.paneIDs
        }
    }

    var paneCount: Int {
        paneIDs.count
    }

    func containsPane(_ id: UUID) -> Bool {
        paneIDs.contains(id)
    }

    func replacingLeaf(_ id: UUID, with replacement: PaneLayout) -> PaneLayout? {
        switch self {
        case .leaf(let leafID):
            return leafID == id ? replacement : nil
        case .split(let axis, let first, let second):
            if let newFirst = first.replacingLeaf(id, with: replacement) {
                return .split(axis: axis, first: newFirst, second: second)
            }
            if let newSecond = second.replacingLeaf(id, with: replacement) {
                return .split(axis: axis, first: first, second: newSecond)
            }
            return nil
        }
    }

    /// Returns the layout with `id` removed, collapsing empty splits. `nil` means no panes remain.
    func removingPane(_ id: UUID) -> PaneLayout? {
        switch self {
        case .leaf(let leafID):
            return leafID == id ? nil : self
        case .split(let axis, let first, let second):
            let newFirst = first.removingPane(id)
            let newSecond = second.removingPane(id)
            switch (newFirst, newSecond) {
            case (nil, nil):
                return nil
            case (let kept?, nil):
                return kept
            case (nil, let kept?):
                return kept
            case (let keptFirst?, let keptSecond?):
                return .split(axis: axis, first: keptFirst, second: keptSecond)
            }
        }
    }
}

struct TerminalPane: Identifiable, Equatable, Sendable {
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

    static func make(startupWorkingDirectory: String?) -> TerminalPane {
        TerminalPane(
            title: AppPaths.displayName,
            currentWorkingDirectory: startupWorkingDirectory
        )
    }
}

/// One terminal tab, which may contain up to four split panes.
struct TerminalSession: Identifiable, Equatable, Sendable {
    static let maxPanes = 4

    let id: UUID
    var panes: [TerminalPane]
    var layout: PaneLayout
    var focusedPaneID: UUID

    init(
        id: UUID = UUID(),
        panes: [TerminalPane],
        layout: PaneLayout,
        focusedPaneID: UUID
    ) {
        self.id = id
        self.panes = panes
        self.layout = layout
        self.focusedPaneID = focusedPaneID
    }

    var focusedPane: TerminalPane? {
        panes.first(where: { $0.id == focusedPaneID }) ?? panes.first
    }

    var title: String {
        focusedPane?.title ?? AppPaths.displayName
    }

    var currentWorkingDirectory: String? {
        focusedPane?.currentWorkingDirectory
    }

    var shellIsRunning: Bool {
        panes.contains(where: \.shellIsRunning)
    }

    var tabLabel: String {
        focusedPane?.tabLabel ?? AppPaths.displayName
    }

    var canSplit: Bool {
        panes.count < Self.maxPanes
    }

    var canCloseFocusedPane: Bool {
        panes.count > 1
    }

    func pane(id: UUID) -> TerminalPane? {
        panes.first(where: { $0.id == id })
    }

    static func make(startupWorkingDirectory: String?) -> TerminalSession {
        let pane = TerminalPane.make(startupWorkingDirectory: startupWorkingDirectory)
        return TerminalSession(
            panes: [pane],
            layout: .leaf(pane.id),
            focusedPaneID: pane.id
        )
    }
}
