import Foundation
import Observation

@MainActor
@Observable
final class ThemeRegistry {
    private let appearanceStore: AppearanceStore
    private let pluginStore: PluginStore

    private(set) var catalog: [ThemeCatalogItem] = []
    private(set) var activeTheme: ThemeDefinition = .fallback
    private(set) var activeBorder: ShellBorderStyle = .defaultBorder
    private(set) var activeTitleBar: ShellBorderStyle = .defaultBorder

    init(appearanceStore: AppearanceStore, pluginStore: PluginStore) {
        self.appearanceStore = appearanceStore
        self.pluginStore = pluginStore
        refresh()
    }

    func refresh() {
        var items = ThemeDefinition.builtIn.map {
            ThemeCatalogItem(theme: $0, sourceName: "Built-in", sourceKind: .builtIn)
        }

        items.append(
            contentsOf: appearanceStore.config.customThemes.map {
                ThemeCatalogItem(theme: $0, sourceName: "Custom", sourceKind: .user)
            }
        )

        if appearanceStore.config.allowPluginThemes {
            for plugin in pluginStore.plugins where plugin.manifest.isEnabled {
                items.append(
                    contentsOf: plugin.manifest.themes.map {
                        ThemeCatalogItem(theme: $0, sourceName: plugin.manifest.name, sourceKind: .plugin)
                    }
                )
            }
        }

        catalog = deduplicate(items)
        let baseTheme = catalog.first(where: { $0.theme.id == appearanceStore.config.activeThemeID })?.theme ?? .fallback
        activeTheme = baseTheme.applying(appearanceStore.config.colorOverrides)
        activeBorder = baseTheme.resolvedBorder(applying: appearanceStore.config.borderOverrides)
        activeTitleBar = baseTheme.resolvedTitleBar(
            shellFallback: activeBorder,
            applying: appearanceStore.config.titleBarOverrides
        )
    }

    private func deduplicate(_ items: [ThemeCatalogItem]) -> [ThemeCatalogItem] {
        var seen = Set<String>()
        return items.filter { item in
            seen.insert(item.theme.id).inserted
        }
    }
}
