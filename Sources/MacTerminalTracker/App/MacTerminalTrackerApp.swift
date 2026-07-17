import AppKit
import SwiftUI

@main
struct MacTerminalTrackerApp: App {
    @State private var viewModel: AppViewModel?
    private let preferencesWindowController: PreferencesWindowController?
    private let launchError: String?

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        AppPaths.migrateLegacyAppSupportIfNeeded()
        Self.configureApplicationMenuTitle()

        do {
            let database = try ActivityDatabase(path: AppPaths.databaseURL)
            let appearanceStore = AppearanceStore()
            let commandStore = CommandStore()
            let pluginStore = PluginStore()
            let commandRegistry = CommandRegistry(commandStore: commandStore, pluginStore: pluginStore)
            let themeRegistry = ThemeRegistry(appearanceStore: appearanceStore, pluginStore: pluginStore)
            let galleryRegistry = GalleryRegistry(appearanceStore: appearanceStore, pluginStore: pluginStore)
            let tracker = ToolTrackerService(database: database)
            let workflowRuntime = WorkflowPluginRuntime()
            let workflowSessions = WorkflowSessionService(database: database, workflowRuntime: workflowRuntime)
            let viewModel = AppViewModel(
                appearanceStore: appearanceStore,
                commandStore: commandStore,
                pluginStore: pluginStore,
                commandRegistry: commandRegistry,
                themeRegistry: themeRegistry,
                galleryRegistry: galleryRegistry,
                tracker: tracker,
                database: database,
                workflowRuntime: workflowRuntime,
                workflowSessions: workflowSessions
            )
            let preferencesWindowController = PreferencesWindowController(viewModel: viewModel)
            viewModel.openPreferencesHandler = {
                preferencesWindowController.show()
            }

            _viewModel = State(initialValue: viewModel)
            self.preferencesWindowController = preferencesWindowController
            self.launchError = nil
        } catch {
            _viewModel = State(initialValue: nil)
            self.preferencesWindowController = nil
            self.launchError = """
            \(AppPaths.displayName) could not open its local data store at
            \(AppPaths.databaseURL.path)

            \(error.localizedDescription)
            """
        }
    }

    var body: some Scene {
        WindowGroup {
            if let viewModel {
                ContentView(viewModel: viewModel)
                    .frame(minWidth: 960, minHeight: 620)
                    .onAppear {
                        viewModel.start()
                    }
                    .onDisappear {
                        viewModel.stop()
                    }
            } else {
                LaunchFailureView(message: launchError ?? "\(AppPaths.displayName) failed to launch.")
                    .frame(minWidth: 720, minHeight: 420)
            }
        }
        .windowResizability(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Tab") {
                    viewModel?.newTab()
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Close Tab") {
                    if viewModel?.closeSelectedTab() == true {
                        NSApp.keyWindow?.close()
                    }
                }
                .keyboardShortcut("w", modifiers: .command)
            }

            CommandGroup(replacing: .pasteboard) {
                Button("Copy") {
                    ActiveTerminalRegistry.copy()
                }
                .keyboardShortcut("c", modifiers: .command)

                Button("Paste") {
                    ActiveTerminalRegistry.paste()
                }
                .keyboardShortcut("v", modifiers: .command)

                Button("Select All") {
                    ActiveTerminalRegistry.selectAll()
                }
                .keyboardShortcut("a", modifiers: .command)
            }

            CommandGroup(after: .pasteboard) {
                Button("Find…") {
                    ActiveTerminalRegistry.performFind(action: .showFindPanel)
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("Find Next") {
                    ActiveTerminalRegistry.performFind(action: .next)
                }
                .keyboardShortcut("g", modifiers: .command)

                Button("Find Previous") {
                    ActiveTerminalRegistry.performFind(action: .previous)
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            }
        }
    }

    private static func configureApplicationMenuTitle() {
        DispatchQueue.main.async {
            NSApp.mainMenu?.item(at: 0)?.submenu?.title = AppPaths.displayName
        }
    }
}

private struct LaunchFailureView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Unable to launch \(AppPaths.displayName)")
                .font(.title2.weight(.semibold))

            Text(message)
                .font(.body.monospaced())
                .textSelection(.enabled)

            Text("Check that the app support folder is writable and that the database file is not locked or corrupted.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(28)
        .background(.background)
    }
}
