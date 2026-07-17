import Foundation

enum RollbackPlanGenerator {
    static func generate(
        session: WorkflowSession,
        rules: RollbackTemplateRules
    ) -> String {
        var lines: [String] = []

        let modifiedPaths = session.fileChanges
            .filter { $0.changeKind == "modified" }
            .map(\.path)
        if !modifiedPaths.isEmpty {
            lines.append(renderCommand("git checkout --", paths: modifiedPaths))
        }

        let addedPaths = session.fileChanges
            .filter { $0.changeKind == "added" }
            .map(\.path)
        if !addedPaths.isEmpty {
            lines.append(renderCommand("git clean -f --", paths: addedPaths))
        }

        if let lastCommand = session.commands.last?.commandText {
            for template in rules.templates {
                if let afterCommand = template.afterCommand,
                   lastCommand.localizedCaseInsensitiveContains(afterCommand) {
                    lines.append(template.template)
                    break
                }
            }
        }

        for change in session.fileChanges {
            for template in rules.templates where template.afterCommand == nil {
                guard template.changeKind == change.changeKind else { continue }
                let rendered = template.template.replacingOccurrences(of: "{{paths}}", with: shellEscape(change.path))
                if !lines.contains(rendered) {
                    lines.append(rendered)
                }
            }
        }

        if lines.isEmpty {
            return "No automatic rollback available for this session."
        }

        return lines.joined(separator: "\n")
    }

    private static func renderCommand(_ prefix: String, paths: [String]) -> String {
        "\(prefix) \(paths.map(shellEscape).joined(separator: " "))"
    }

    private static func shellEscape(_ path: String) -> String {
        guard path.contains(where: { $0.isWhitespace || "'\"\\$".contains($0) }) else {
            return path
        }

        let escaped = path.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }
}
