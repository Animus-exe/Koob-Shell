import Foundation

enum WorkflowReportGenerator {
    enum Format: String, Sendable {
        case text
        case markdown
        case json
    }

    static func generate(session: WorkflowSession, rollbackPlan: String?, format: Format = .text) -> String {
        switch format {
        case .text:
            return textReport(session: session, rollbackPlan: rollbackPlan)
        case .markdown:
            return markdownReport(session: session, rollbackPlan: rollbackPlan)
        case .json:
            return jsonReport(session: session, rollbackPlan: rollbackPlan)
        }
    }

    private static func textReport(session: WorkflowSession, rollbackPlan: String?) -> String {
        var lines: [String] = []
        lines.append("Project: \(session.projectName ?? "unknown")")
        if let root = session.projectRoot {
            lines.append("Root: \(root)")
        }
        lines.append("Goal detected: \(session.detectedGoal ?? "not detected")")
        lines.append("Outcome: \(session.outcome.rawValue)")
        lines.append("Commands run:")

        for command in session.commands {
            let status: String
            if let exitCode = command.exitCode {
                status = exitCode == 0 ? "ok" : "exit \(exitCode)"
            } else {
                status = "running"
            }
            lines.append("  \(command.sequence). [\(command.riskLevel.rawValue)/\(status)] \(command.commandText)")
        }

        lines.append("Files changed:")
        if session.fileChanges.isEmpty {
            lines.append("  (none detected)")
        } else {
            for change in session.fileChanges {
                lines.append("  - \(change.path)")
            }
        }

        lines.append("Safe rollback:")
        let plan = rollbackPlan ?? session.rollbackPlanJSON ?? "No rollback plan generated."
        for line in plan.split(separator: "\n", omittingEmptySubsequences: false) {
            lines.append("  \(line)")
        }

        return lines.joined(separator: "\n")
    }

    private static func markdownReport(session: WorkflowSession, rollbackPlan: String?) -> String {
        var lines: [String] = ["# Workflow Debug Report", ""]
        lines.append("## Project")
        lines.append(session.projectName ?? "unknown")
        lines.append("")
        lines.append("## Goal")
        lines.append(session.detectedGoal ?? "not detected")
        lines.append("")
        lines.append("## Outcome")
        lines.append(session.outcome.rawValue)
        lines.append("")
        lines.append("## Commands")
        for command in session.commands {
            lines.append("\(command.sequence). `\(command.commandText)` (\(command.riskLevel.rawValue))")
        }
        lines.append("")
        lines.append("## Safe Rollback")
        lines.append("```")
        lines.append(rollbackPlan ?? session.rollbackPlanJSON ?? "No rollback plan generated.")
        lines.append("```")
        return lines.joined(separator: "\n")
    }

    private static func jsonReport(session: WorkflowSession, rollbackPlan: String?) -> String {
        let payload: [String: Any] = [
            "project": session.projectName ?? "unknown",
            "projectRoot": session.projectRoot ?? "",
            "goal": session.detectedGoal ?? "",
            "outcome": session.outcome.rawValue,
            "commands": session.commands.map {
                [
                    "sequence": $0.sequence,
                    "command": $0.commandText,
                    "exitCode": $0.exitCode ?? -1,
                    "risk": $0.riskLevel.rawValue,
                ] as [String: Any]
            },
            "filesChanged": session.fileChanges.map(\.path),
            "rollbackPlan": rollbackPlan ?? session.rollbackPlanJSON ?? "",
        ]

        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}
