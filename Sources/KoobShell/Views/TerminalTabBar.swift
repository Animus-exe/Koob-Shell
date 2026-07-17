import SwiftUI

struct TerminalTabBar: View {
    let sessions: [TerminalSession]
    let selectedSessionID: UUID
    let onSelect: (UUID) -> Void
    let onClose: (UUID) -> Void
    let onNewTab: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(sessions) { session in
                        TerminalTabItem(
                            title: session.tabLabel,
                            isSelected: session.id == selectedSessionID,
                            isRunning: session.shellIsRunning,
                            onSelect: { onSelect(session.id) },
                            onClose: { onClose(session.id) }
                        )
                    }
                }
                .padding(.leading, 4)
            }

            Button(action: onNewTab) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("New Tab")
            .padding(.horizontal, 4)
        }
        .frame(height: 26)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.55))
        .overlay(alignment: .bottom) {
            Divider().opacity(0.55)
        }
    }
}

private struct TerminalTabItem: View {
    let title: String
    let isSelected: Bool
    let isRunning: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isRunning ? Color.green.opacity(0.8) : Color.secondary.opacity(0.3))
                .frame(width: 4, height: 4)

            Text(title)
                .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .lineLimit(1)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 12, height: 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Close Tab")
        }
        .padding(.horizontal, 7)
        .frame(height: 26)
        .background(alignment: .bottom) {
            Rectangle()
                .fill(isSelected ? Color.accentColor.opacity(0.85) : Color.clear)
                .frame(height: 1.5)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .contextMenu {
            Button("Close Tab", action: onClose)
        }
    }
}
