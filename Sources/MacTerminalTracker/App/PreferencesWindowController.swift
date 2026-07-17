import AppKit
import SwiftUI

@MainActor
final class PreferencesWindowController {
    private let window: NSWindow

    init(viewModel: AppViewModel) {
        let hostingController = NSHostingController(rootView: PreferencesView(viewModel: viewModel))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Preferences"
        window.identifier = NSUserInterfaceItemIdentifier(AppPaths.preferencesWindowIdentifier)
        window.setContentSize(NSSize(width: 480, height: 580))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        window.toolbarStyle = .preference
        window.titleVisibility = .visible
        window.isMovableByWindowBackground = false
        self.window = window
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
