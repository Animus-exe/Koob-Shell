import Foundation
import Observation

@MainActor
@Observable
final class GalleryRegistry {
    private let appearanceStore: AppearanceStore
    private let pluginStore: PluginStore

    private(set) var catalog: [GalleryCatalogItem] = []
    private(set) var entries: [AsciiArtEntry] = []

    init(appearanceStore: AppearanceStore, pluginStore: PluginStore) {
        self.appearanceStore = appearanceStore
        self.pluginStore = pluginStore
    }

    func refresh() {
        guard appearanceStore.config.allowPluginGalleries else {
            catalog = []
            entries = []
            return
        }

        var items: [GalleryCatalogItem] = []
        var mergedEntries: [AsciiArtEntry] = []

        for plugin in pluginStore.plugins where plugin.manifest.isEnabled {
            guard let gallery = plugin.manifest.gallery else {
                continue
            }

            let artDirectories = AsciiArtGallery.resolveArtDirectories(
                pluginID: plugin.manifest.id,
                gallery: gallery,
                installedRoot: plugin.rootURL
            )
            let loadedEntries = AsciiArtGallery.loadEntries(from: artDirectories)
            guard !loadedEntries.isEmpty else {
                continue
            }

            let prefixedEntries = loadedEntries.map { $0.prefixed(pluginID: plugin.manifest.id) }
            items.append(
                GalleryCatalogItem(
                    pluginID: plugin.manifest.id,
                    pluginName: plugin.manifest.name,
                    entries: prefixedEntries
                )
            )
            mergedEntries.append(contentsOf: prefixedEntries)
        }

        catalog = items
        entries = mergedEntries.sorted { lhs, rhs in
            let leftIsKoob = lhs.id.localizedCaseInsensitiveContains("koob")
            let rightIsKoob = rhs.id.localizedCaseInsensitiveContains("koob")
            if leftIsKoob != rightIsKoob {
                return leftIsKoob
            }
            if lhs.isAnimated != rhs.isAnimated {
                return lhs.isAnimated
            }
            return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
        }
    }
}
