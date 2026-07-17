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
                HStack(spacing: 4) {
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
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }

            Button(action: onNewTab) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 24)
            }
            .buttonStyle(.plain)
            .help("New Tab")
            .padding(.trailing, 8)
        }
        .background(.bar)
    }
}

private struct TerminalTabItem: View {
    let title: String
    let isSelected: Bool
    let isRunning: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isRunning ? Color.green.opacity(0.85) : Color.secondary.opacity(0.35))
                .frame(width: 6, height: 6)

            Text(title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close Tab")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.primary.opacity(0.12) : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onTapGesture(perform: onSelect)
        .contextMenu {
            Button("Close Tab", action: onClose)
        }
    }
}
