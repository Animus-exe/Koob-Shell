import Foundation

enum SessionGoalDetector {
    static func detectGoal(from commands: [WorkflowCommand], rules: GoalPatternRules) -> String? {
        let commandTexts = commands.map(\.commandText)
        let hasFailure = commands.contains { ($0.exitCode ?? 0) != 0 }

        var bestLabel: String?
        var bestScore = 0

        for goal in rules.goals {
            if goal.requiresFailures == true, !hasFailure {
                continue
            }

            let score = goal.signals.reduce(0) { partial, signal in
                partial + (commandTexts.contains(where: { $0.localizedCaseInsensitiveContains(signal) }) ? 1 : 0)
            }

            if score > bestScore {
                bestScore = score
                bestLabel = goal.label
            }
        }

        return bestLabel
    }
}
