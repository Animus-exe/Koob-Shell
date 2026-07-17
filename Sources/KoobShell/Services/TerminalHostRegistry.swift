import AppKit

/// Keeps terminal host views alive across SwiftUI layout changes (e.g. split/unsplit).
@MainActor
enum TerminalHostRegistry {
    private static var hosts: [UUID: TerminalHostView] = [:]

    static func host(for paneID: UUID) -> TerminalHostView {
        if let existing = hosts[paneID] {
            return existing
        }
        let host = TerminalHostView()
        hosts[paneID] = host
        return host
    }

    static func remove(paneID: UUID) {
        if let host = hosts.removeValue(forKey: paneID) {
            host.removeFromSuperview()
            host.prepareForRemoval()
        }
    }

    static func removeAll(paneIDs: [UUID]) {
        for id in paneIDs {
            remove(paneID: id)
        }
    }
}

/// Container that re-parents a shared `TerminalHostView` without destroying it.
final class TerminalHostContainerView: NSView {
    private(set) weak var hostedView: TerminalHostView?

    override var isOpaque: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func attach(_ host: TerminalHostView) {
        if hostedView === host, host.superview === self {
            return
        }
        hostedView?.removeFromSuperview()
        host.removeFromSuperview()
        hostedView = host
        host.translatesAutoresizingMaskIntoConstraints = true
        host.autoresizingMask = [.width, .height]
        host.frame = bounds
        addSubview(host)
    }

    func detachHost() {
        hostedView?.removeFromSuperview()
        hostedView = nil
    }

    override func layout() {
        super.layout()
        hostedView?.frame = bounds
    }
}
