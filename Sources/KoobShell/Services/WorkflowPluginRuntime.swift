import Foundation
import Observation

struct WorkflowPluginSettings: Codable, Hashable, Sendable {
    var captureEnabled: Bool
    var destructiveWarnings: DestructiveWarningMode
    var autoSummaryOnExit: Bool

    static let `default` = WorkflowPluginSettings(
        captureEnabled: true,
        destructiveWarnings: .warn,
        autoSummaryOnExit: true
    )
}

enum WorkflowPluginSettingsStore {
    static func load(pluginID: String, defaults: WorkflowPreferences) -> WorkflowPluginSettings {
        let url = AppPaths.pluginSettingsURL(pluginID: pluginID)
        guard let data = try? Data(contentsOf: url),
              let settings = try? JSONDecoder().decode(WorkflowPluginSettings.self, from: data) else {
            return WorkflowPluginSettings(
                captureEnabled: defaults.captureEnabled,
                destructiveWarnings: defaults.destructiveWarnings,
                autoSummaryOnExit: defaults.autoSummaryOnExit
            )
        }
        return settings
    }

    static func save(_ settings: WorkflowPluginSettings, pluginID: String) throws {
        let url = AppPaths.pluginSettingsURL(pluginID: pluginID)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(settings).write(to: url, options: .atomic)
    }
}

@MainActor
@Observable
final class WorkflowPluginRuntime {
    private(set) var activePlugin: LoadedPlugin?
    private(set) var rules: LoadedWorkflowRules = .empty
    private(set) var settings: WorkflowPluginSettings = .default
    private(set) var activationError: String?

    var isActive: Bool {
        activePlugin != nil
    }

    var activePluginID: String? {
        activePlugin?.manifest.id
    }

    var preferences: WorkflowPreferences {
        activePlugin?.manifest.workflow?.preferences ?? .default
    }

    var uiConfig: WorkflowUIConfig {
        activePlugin?.manifest.workflow?.ui ?? .default
    }

    func refresh(using pluginStore: PluginStore) {
        activationError = nil

        guard let plugin = pluginStore.plugins.first(where: {
            $0.manifest.isEnabled && $0.manifest.workflow != nil
        }) else {
            deactivate()
            return
        }

        do {
            try activate(plugin: plugin)
        } catch {
            activationError = error.localizedDescription
            deactivate()
        }
    }

    private func activate(plugin: LoadedPlugin) throws {
        if activePlugin?.id == plugin.id, isActive {
            rules = (try? PluginRuleLoader.load(from: plugin)) ?? .empty
            settings = WorkflowPluginSettingsStore.load(
                pluginID: plugin.manifest.id,
                defaults: plugin.manifest.workflow?.preferences ?? .default
            )
            return
        }

        try PluginLifecycleCoordinator.install(plugin: plugin)
        activePlugin = plugin
        rules = try PluginRuleLoader.load(from: plugin)
        settings = WorkflowPluginSettingsStore.load(
            pluginID: plugin.manifest.id,
            defaults: plugin.manifest.workflow?.preferences ?? .default
        )
    }

    private func deactivate() {
        if let plugin = activePlugin {
            PluginLifecycleCoordinator.uninstall(plugin: plugin)
        }
        activePlugin = nil
        rules = .empty
        settings = .default
    }

    func updateSettings(_ settings: WorkflowPluginSettings) throws {
        guard let plugin = activePlugin else { return }
        try WorkflowPluginSettingsStore.save(settings, pluginID: plugin.manifest.id)
        self.settings = settings
    }

    func shellIntegrationEnvironment(sessionID: String) -> [String: String] {
        guard isActive, let plugin = activePlugin, let workflow = plugin.manifest.workflow else {
            return [:]
        }

        var environment: [String: String] = [
            workflow.shellIntegration.envFlag: "1",
            workflow.shellIntegration.sessionEnvVar: sessionID,
            "KOOBSHELL_PLUGIN_ID": plugin.manifest.id,
            "KOOBSHELL_CAPTURE_ENABLED": settings.captureEnabled ? "1" : "0",
            "KOOBSHELL_DESTRUCTIVE_WARNINGS": settings.destructiveWarnings.rawValue,
        ]

        let zshHook = plugin.rootURL.appendingPathComponent(workflow.shellIntegration.zshHook)
        let bashHook = plugin.rootURL.appendingPathComponent(workflow.shellIntegration.bashHook)
        environment["KOOBSHELL_ZSH_HOOK"] = zshHook.path
        environment["KOOBSHELL_BASH_HOOK"] = bashHook.path

        return environment
    }
}

enum PluginLifecycleCoordinator {
    static func install(plugin: LoadedPlugin) throws {
        guard let workflow = plugin.manifest.workflow else { return }

        let fileManager = FileManager.default
        try fileManager.createDirectory(at: AppPaths.binDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: AppPaths.shellDirectory, withIntermediateDirectories: true)

        let cliSource = plugin.rootURL.appendingPathComponent("bin/\(workflow.cliName)")
        let cliDestination = AppPaths.binDirectory.appendingPathComponent(workflow.cliName)

        if fileManager.fileExists(atPath: cliDestination.path) {
            try fileManager.removeItem(at: cliDestination)
        }
        try fileManager.copyItem(at: cliSource, to: cliDestination)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: cliDestination.path)

        let zshSource = plugin.rootURL.appendingPathComponent(workflow.shellIntegration.zshHook)
        let bashSource = plugin.rootURL.appendingPathComponent(workflow.shellIntegration.bashHook)
        let zshDestination = AppPaths.shellDirectory.appendingPathComponent(zshSource.lastPathComponent)
        let bashDestination = AppPaths.shellDirectory.appendingPathComponent(bashSource.lastPathComponent)

        for (source, destination) in [(zshSource, zshDestination), (bashSource, bashDestination)] {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: source, to: destination)
        }

        try installShellOverlays(
            zshHookPath: zshDestination.path,
            bashHookPath: bashDestination.path,
            fileManager: fileManager
        )
    }

    private static func installShellOverlays(
        zshHookPath: String,
        bashHookPath: String,
        fileManager: FileManager
    ) throws {
        try fileManager.createDirectory(at: AppPaths.zdotdirOverlayDirectory, withIntermediateDirectories: true)

        let zshOverlay = """
        # Koob Shell workflow integration overlay
        if [[ -f "$HOME/.zshrc" ]]; then
          source "$HOME/.zshrc"
        fi
        if [[ -f "\(zshHookPath)" ]]; then
          source "\(zshHookPath)"
        fi
        """
        try zshOverlay.write(to: AppPaths.zdotdirOverlayDirectory.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)

        let bashOverlay = """
        # Koob Shell workflow integration overlay
        if [[ -f "$HOME/.bashrc" ]]; then
          source "$HOME/.bashrc"
        fi
        if [[ -f "\(bashHookPath)" ]]; then
          source "\(bashHookPath)"
        fi
        """
        try bashOverlay.write(to: AppPaths.bashOverlayRCURL, atomically: true, encoding: .utf8)
    }

    static func uninstall(plugin: LoadedPlugin) {
        let fileManager = FileManager.default
        guard let workflow = plugin.manifest.workflow else { return }

        let cliDestination = AppPaths.binDirectory.appendingPathComponent(workflow.cliName)
        try? fileManager.removeItem(at: cliDestination)

        let zshHook = URL(fileURLWithPath: workflow.shellIntegration.zshHook).lastPathComponent
        let bashHook = URL(fileURLWithPath: workflow.shellIntegration.bashHook).lastPathComponent
        try? fileManager.removeItem(at: AppPaths.shellDirectory.appendingPathComponent(zshHook))
        try? fileManager.removeItem(at: AppPaths.shellDirectory.appendingPathComponent(bashHook))
    }
}
