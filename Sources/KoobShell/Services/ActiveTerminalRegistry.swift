import AppKit

@MainActor
enum ActiveTerminalRegistry {
    private(set) static weak var current: TrackerTerminalView?

    static func setCurrent(_ terminal: TrackerTerminalView?) {
        current = terminal
    }

    static func focusCurrent() {
        guard let current, let window = current.window else { return }
        window.makeFirstResponder(current)
    }

    static func performFind(action: NSFindPanelAction) {
        guard let current else { return }
        let item = NSMenuItem()
        item.tag = Int(action.rawValue)
        current.performFindPanelAction(item)
    }

    static func copy() {
        current?.copy(NSNull())
    }

    static func paste() {
        current?.paste(NSNull())
    }

    static func selectAll() {
        current?.selectAll(NSNull())
    }
}
