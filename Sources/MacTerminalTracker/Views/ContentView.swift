import AppKit
import SwiftUI

struct ContentView: View {
  @Bindable var viewModel: AppViewModel

  var body: some View {
    let appearance = viewModel.appearanceStore.config
    let titleBar = viewModel.activeTitleBar
    let border = viewModel.activeBorder

    VStack(spacing: 0) {
      TerminalTabBar(
        sessions: viewModel.sessions.sessions,
        selectedSessionID: viewModel.sessions.selectedSessionID,
        onSelect: viewModel.selectTab,
        onClose: { id in
          if viewModel.closeTab(id) {
            NSApp.keyWindow?.close()
          }
        },
        onNewTab: viewModel.newTab
      )

      ZStack {
        ShellThemeBackground(
          theme: viewModel.activeTheme,
          border: border
        )

        AsciiGalleryPluginView(
          entries: viewModel.galleryRegistry.entries,
          appearance: appearance
        )

        HStack(spacing: 0) {
          ZStack {
            ForEach(viewModel.sessions.sessions) { session in
              let isSelected = session.id == viewModel.sessions.selectedSessionID
              TerminalTextView(
                theme: viewModel.activeTheme,
                appearance: appearance,
                border: border,
                titleBar: titleBar,
                terminalTitle: session.title,
                currentWorkingDirectory: session.currentWorkingDirectory ?? viewModel.startupWorkingDirectory,
                workflowSessionID: session.workflowSessionID,
                workflowShellEnvironment: viewModel.workflowRuntime.shellIntegrationEnvironment(
                  sessionID: session.workflowSessionID
                ),
                useWorkflowShellOverlay: viewModel.workflowRuntime.isActive,
                isSelected: isSelected,
                focusToken: isSelected ? viewModel.focusToken : 0,
                onReady: {
                  viewModel.handleTerminalReady(sessionID: session.id)
                },
                onStartFailure: { reason in
                  viewModel.handleTerminalLaunchFailure(sessionID: session.id, reason: reason)
                },
                onActivity: viewModel.noteTerminalActivity,
                onExit: { exitCode in
                  viewModel.handleTerminalExit(sessionID: session.id, exitCode: exitCode)
                },
                onTitleChange: { title in
                  viewModel.updateTerminalTitle(sessionID: session.id, title: title)
                },
                onDirectoryChange: { directory in
                  viewModel.updateWorkingDirectory(sessionID: session.id, directory: directory)
                },
                onOpenPreferences: viewModel.openPreferencesWindow
              )
              .opacity(isSelected ? 1 : 0)
              .allowsHitTesting(isSelected)
            }
          }
          .background(Color.clear)

          if shouldShowWorkflowInspector {
            Divider()
            SessionInspectorView(viewModel: viewModel)
              .frame(width: inspectorWidth)
          }
        }
      }
    }
    .background {
      ShellWindowReader(
        theme: viewModel.activeTheme,
        border: border,
        titleBar: titleBar
      )
    }
    .toolbarBackground(titleBarToolbarVisibility, for: .windowToolbar)
    .toolbarBackground(titleBarToolbarFill, for: .windowToolbar)
    .onChange(of: viewModel.activeTitleBar) { _, _ in
      refreshMainWindowChrome()
    }
    .onChange(of: viewModel.activeBorder) { _, _ in
      refreshMainWindowChrome()
    }
    .onChange(of: viewModel.appearanceStore.config.activeThemeID) { _, _ in
      refreshMainWindowChrome()
    }
  }

  private var titleBarToolbarVisibility: Visibility {
    viewModel.activeTitleBar.usesCustomShellChrome ? .visible : .automatic
  }

  private var titleBarToolbarFill: some ShapeStyle {
    ShellStyleRendering.swiftUIFill(
      style: viewModel.activeTitleBar,
      themeBackgroundHex: viewModel.activeTheme.backgroundColor
    )
  }

  private var shouldShowWorkflowInspector: Bool {
    viewModel.workflowRuntime.isActive
      && viewModel.workflowRuntime.uiConfig.inspectorPanelEnabled
      && viewModel.showWorkflowInspector
  }

  private var inspectorWidth: CGFloat {
    CGFloat(viewModel.workflowRuntime.uiConfig.defaultPanelWidth)
  }

  private func refreshMainWindowChrome() {
    guard let window = NSApp.windows.first(where: {
      $0.identifier?.rawValue == AppPaths.mainWindowIdentifier
    }) else {
      return
    }

    ShellWindowChromeApplier.apply(
      window: window,
      theme: viewModel.activeTheme,
      border: viewModel.activeBorder,
      titleBar: viewModel.activeTitleBar
    )
  }
}
