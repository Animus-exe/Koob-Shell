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

        // Only mount the selected tab. Hosts stay alive in TerminalHostRegistry
        // so switching tabs reattaches without killing shells.
        if let session = viewModel.sessions.selectedSession {
          TerminalSplitContainer(
            viewModel: viewModel,
            session: session,
            isTabSelected: true
          )
        }
      }
      .background(Color.clear)
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
