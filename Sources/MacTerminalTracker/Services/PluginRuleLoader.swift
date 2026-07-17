import Foundation

enum PluginRuleLoader {
    static func load(from plugin: LoadedPlugin) throws -> LoadedWorkflowRules {
        let rulesDirectory = plugin.rootURL.appendingPathComponent(
            plugin.manifest.workflow?.rulesDirectory ?? "rules",
            isDirectory: true
        )

        let destructiveURL = rulesDirectory.appendingPathComponent("destructive-commands.json")
        let goalsURL = rulesDirectory.appendingPathComponent("goal-patterns.json")
        let rollbackURL = rulesDirectory.appendingPathComponent("rollback-templates.json")

        let decoder = JSONDecoder()

        let destructive: DestructiveCommandRules
        if FileManager.default.fileExists(atPath: destructiveURL.path),
           let data = try? Data(contentsOf: destructiveURL) {
            destructive = try decoder.decode(DestructiveCommandRules.self, from: data)
        } else {
            destructive = DestructiveCommandRules(patterns: [])
        }

        let goals: GoalPatternRules
        if FileManager.default.fileExists(atPath: goalsURL.path),
           let data = try? Data(contentsOf: goalsURL) {
            goals = try decoder.decode(GoalPatternRules.self, from: data)
        } else {
            goals = GoalPatternRules(goals: [])
        }

        let rollback: RollbackTemplateRules
        if FileManager.default.fileExists(atPath: rollbackURL.path),
           let data = try? Data(contentsOf: rollbackURL) {
            rollback = try decoder.decode(RollbackTemplateRules.self, from: data)
        } else {
            rollback = RollbackTemplateRules(templates: [])
        }

        return LoadedWorkflowRules(destructive: destructive, goals: goals, rollback: rollback)
    }
}
