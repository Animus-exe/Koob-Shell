import SwiftUI

struct SessionSummaryPanel: View {
    let session: WorkflowSession
    let rollbackPlan: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(session.projectName ?? "Unknown project", systemImage: "folder")
                .font(.headline)

            if let goal = session.detectedGoal {
                Text("Goal: \(goal)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Outcome")
                    .foregroundStyle(.secondary)
                Spacer()
                OutcomeBadge(outcome: session.outcome)
            }

            if !session.fileChanges.isEmpty {
                Text("Files changed")
                    .font(.subheadline.weight(.semibold))
                ForEach(session.fileChanges.prefix(6)) { change in
                    Text(change.path)
                        .font(.caption)
                        .lineLimit(1)
                }
            }

            Text("Safe rollback")
                .font(.subheadline.weight(.semibold))
            Text(rollbackPlan)
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct OutcomeBadge: View {
    let outcome: SessionOutcome

    var body: some View {
        Text(outcome.rawValue)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor.opacity(0.2), in: Capsule())
            .foregroundStyle(backgroundColor)
    }

    private var backgroundColor: Color {
        switch outcome {
        case .success: .green
        case .failure: .red
        case .mixed: .orange
        case .inProgress: .blue
        }
    }
}

struct SessionInspectorView: View {
    @Bindable var viewModel: AppViewModel
    @State private var searchQuery = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            sessionPicker
            Divider()
            commandTimeline
            if let session = viewModel.workflowSessions.selectedSession {
                Divider()
                SessionSummaryPanel(
                    session: session,
                    rollbackPlan: viewModel.workflowSessions.rollbackPlan(for: session)
                )
                .padding(12)
            }
        }
        .frame(minWidth: 280)
        .background(.regularMaterial)
        .onAppear {
            viewModel.workflowSessions.refreshRecentSessions()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Workflow Intelligence")
                .font(.headline)
            HStack {
                TextField("Search sessions", text: $searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        if searchQuery.isEmpty {
                            viewModel.workflowSessions.refreshRecentSessions()
                        } else {
                            viewModel.workflowSessions.searchSessions(query: searchQuery)
                        }
                    }
                Button("Refresh") {
                    searchQuery = ""
                    viewModel.workflowSessions.refreshRecentSessions()
                }
            }
        }
        .padding(12)
    }

    private var sessionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.workflowSessions.recentSessions, id: \.id) { session in
                    Button {
                        viewModel.workflowSessions.selectSession(session)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.projectName ?? "Session")
                                .font(.caption.weight(.semibold))
                            Text(session.detectedGoal ?? session.outcome.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            session.id == viewModel.workflowSessions.selectedSession?.id
                                ? Color.accentColor.opacity(0.18)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var commandTimeline: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                if let session = viewModel.workflowSessions.selectedSession {
                    ForEach(session.commands) { command in
                        CommandTimelineRow(command: command)
                    }
                } else {
                    Text("No workflow sessions recorded yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(12)
                }
            }
            .padding(12)
        }
    }
}

private struct CommandTimelineRow: View {
    let command: WorkflowCommand

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(command.sequence)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .trailing)

            VStack(alignment: .leading, spacing: 4) {
                Text(command.commandText)
                    .font(.caption.monospaced())
                    .lineLimit(2)

                HStack(spacing: 6) {
                    RiskBadge(risk: command.riskLevel)
                    if let exitCode = command.exitCode {
                        Text(exitCode == 0 ? "ok" : "exit \(exitCode)")
                            .font(.caption2)
                            .foregroundStyle(exitCode == 0 ? .green : .red)
                    }
                    if let cwd = command.workingDirectory {
                        Text((cwd as NSString).abbreviatingWithTildeInPath)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct RiskBadge: View {
    let risk: CommandRiskLevel

    var body: some View {
        Text(risk.rawValue)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch risk {
        case .safe, .low: .secondary
        case .medium: .orange
        case .high: .red
        case .destructive: .pink
        }
    }
}
