import AppKit
import SwiftUI

struct TerminalSplitContainer: View {
    @Bindable var viewModel: AppViewModel
    let session: TerminalSession
    let isTabSelected: Bool

    var body: some View {
        TerminalPaneLayoutView(
            viewModel: viewModel,
            session: session,
            layout: session.layout,
            isTabSelected: isTabSelected
        )
    }
}

private struct TerminalPaneLayoutView: View {
    @Bindable var viewModel: AppViewModel
    let session: TerminalSession
    let layout: PaneLayout
    let isTabSelected: Bool

    var body: some View {
        switch layout {
        case .leaf(let paneID):
            if let pane = session.pane(id: paneID) {
                TerminalPaneHost(
                    viewModel: viewModel,
                    session: session,
                    pane: pane,
                    isTabSelected: isTabSelected
                )
            }

        case .split(let axis, let first, let second):
            switch axis {
            case .horizontal:
                HSplitView {
                    TerminalPaneLayoutView(
                        viewModel: viewModel,
                        session: session,
                        layout: first,
                        isTabSelected: isTabSelected
                    )
                    TerminalPaneLayoutView(
                        viewModel: viewModel,
                        session: session,
                        layout: second,
                        isTabSelected: isTabSelected
                    )
                }
            case .vertical:
                VSplitView {
                    TerminalPaneLayoutView(
                        viewModel: viewModel,
                        session: session,
                        layout: first,
                        isTabSelected: isTabSelected
                    )
                    TerminalPaneLayoutView(
                        viewModel: viewModel,
                        session: session,
                        layout: second,
                        isTabSelected: isTabSelected
                    )
                }
            }
        }
    }
}

private struct TerminalPaneHost: View {
    @Bindable var viewModel: AppViewModel
    let session: TerminalSession
    let pane: TerminalPane
    let isTabSelected: Bool

    private var isFocusedPane: Bool {
        isTabSelected && session.focusedPaneID == pane.id
    }

    var body: some View {
        let appearance = viewModel.appearanceStore.config
        let titleBar = viewModel.activeTitleBar
        let border = viewModel.activeBorder

        TerminalTextView(
            paneID: pane.id,
            theme: viewModel.activeTheme,
            appearance: appearance,
            border: border,
            titleBar: titleBar,
            terminalTitle: pane.title,
            currentWorkingDirectory: pane.currentWorkingDirectory ?? viewModel.startupWorkingDirectory,
            workflowSessionID: pane.workflowSessionID,
            workflowShellEnvironment: viewModel.workflowRuntime.shellIntegrationEnvironment(
                sessionID: pane.workflowSessionID
            ),
            useWorkflowShellOverlay: viewModel.workflowRuntime.isActive,
            isSelected: isFocusedPane,
            canSplit: session.canSplit,
            canClosePane: session.panes.count > 1,
            focusToken: isFocusedPane ? viewModel.focusToken : 0,
            onReady: {
                viewModel.handleTerminalReady(tabID: session.id, paneID: pane.id)
            },
            onStartFailure: { reason in
                viewModel.handleTerminalLaunchFailure(tabID: session.id, paneID: pane.id, reason: reason)
            },
            onExit: { exitCode in
                viewModel.handleTerminalExit(tabID: session.id, paneID: pane.id, exitCode: exitCode)
            },
            onTitleChange: { title in
                viewModel.updateTerminalTitle(tabID: session.id, paneID: pane.id, title: title)
            },
            onDirectoryChange: { directory in
                viewModel.updateWorkingDirectory(tabID: session.id, paneID: pane.id, directory: directory)
            },
            onFocus: {
                viewModel.focusPane(tabID: session.id, paneID: pane.id)
            },
            onSplitVertically: {
                _ = viewModel.splitPane(tabID: session.id, paneID: pane.id, axis: .horizontal)
            },
            onSplitHorizontally: {
                _ = viewModel.splitPane(tabID: session.id, paneID: pane.id, axis: .vertical)
            },
            onClosePane: {
                if viewModel.closePane(tabID: session.id, paneID: pane.id) {
                    NSApp.keyWindow?.close()
                }
            },
            onOpenPreferences: viewModel.openPreferencesWindow
        )
        .id(pane.id)
        .frame(minWidth: 160, minHeight: 100)
    }
}
