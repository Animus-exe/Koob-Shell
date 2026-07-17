import Foundation
import Observation

@MainActor
@Observable
final class CommandRegistry {
    private let commandStore: CommandStore
    private let pluginStore: PluginStore

    private(set) var commands: [CommandCatalogEntry] = []

    init(commandStore: CommandStore, pluginStore: PluginStore) {
        self.commandStore = commandStore
        self.pluginStore = pluginStore
        refresh()
    }

    func refresh() {
        var catalog = commandStore.commands.map {
            CommandCatalogEntry(command: $0, sourceName: "Custom", sourceKind: .user)
        }

        for plugin in pluginStore.plugins where plugin.manifest.isEnabled {
            catalog.append(
                contentsOf: plugin.manifest.commands.map {
                    CommandCatalogEntry(command: $0, sourceName: plugin.manifest.name, sourceKind: .plugin)
                }
            )
        }

        commands = catalog.sorted {
            if $0.sourceKind == $1.sourceKind {
                return $0.command.name.localizedCaseInsensitiveCompare($1.command.name) == .orderedAscending
            }
            return $0.sourceKind.rawValue < $1.sourceKind.rawValue
        }
    }
}
