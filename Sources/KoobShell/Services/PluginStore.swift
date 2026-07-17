import Foundation
import Observation

@MainActor
@Observable
final class PluginStore {
    var plugins: [LoadedPlugin] = []
    var loadError: String?

    init() {
        reload()
    }

    func reload() {
        do {
            try ensurePluginFiles()
            let fileManager = FileManager.default
            let pluginFolders = try fileManager.contentsOfDirectory(
                at: AppPaths.pluginsDirectory,
                includingPropertiesForKeys: nil
            )

            var loaded: [LoadedPlugin] = []
            for folder in pluginFolders {
                let manifestURL = folder.appendingPathComponent("plugin.json")
                guard fileManager.fileExists(atPath: manifestURL.path) else { continue }
                let data = try Data(contentsOf: manifestURL)
                let manifest = try PluginCodec.decode(from: data)
                loaded.append(LoadedPlugin(manifest: manifest, manifestURL: manifestURL))
            }

            plugins = loaded.sorted { $0.manifest.name.localizedCaseInsensitiveCompare($1.manifest.name) == .orderedAscending }
            loadError = nil
        } catch {
            plugins = []
            loadError = "Plugin loading fallback active: \(error.localizedDescription)"
        }
    }

    /// Persists `isEnabled` on the plugin's `plugin.json` and updates the in-memory catalog.
    func setEnabled(pluginID: String, isEnabled: Bool) throws {
        guard let index = plugins.firstIndex(where: { $0.manifest.id == pluginID }) else {
            throw PluginStoreError.pluginNotFound(pluginID)
        }

        var plugin = plugins[index]
        guard plugin.manifest.isEnabled != isEnabled else {
            return
        }

        plugin.manifest.isEnabled = isEnabled
        let data = try PluginCodec.encode(plugin.manifest)
        try data.write(to: plugin.manifestURL, options: .atomic)
        plugins[index] = plugin
    }

    private func ensurePluginFiles() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: AppPaths.pluginsDirectory, withIntermediateDirectories: true, attributes: nil)

        try seedJSONPlugin(
            id: "git-helper-pack",
            resourceName: "git-helper-pack",
            fileManager: fileManager
        )
        try seedBundledPluginFolder(
            id: "ascii-gallery",
            fileManager: fileManager
        )
        try seedBundledPluginFolder(
            id: "shell-theme-pack",
            fileManager: fileManager
        )
        try seedBundledPluginFolder(
            id: "workflow-intelligence",
            fileManager: fileManager
        )
        try ensureDefaultKoobArt(fileManager: fileManager)
    }

    private func ensureDefaultKoobArt(fileManager: FileManager) throws {
        let artNames = ["00-koob.json", "01-koob.json", "02-koob.json", "03-koob.json"]
        let artDirectory = AppPaths.pluginsDirectory
            .appendingPathComponent("ascii-gallery", isDirectory: true)
            .appendingPathComponent("Ascii_art", isDirectory: true)

        guard let bundledFolder = bundledPluginDirectory(id: "ascii-gallery") else {
            return
        }

        let bundledArtDirectory = bundledFolder.appendingPathComponent("Ascii_art", isDirectory: true)
        try fileManager.createDirectory(at: artDirectory, withIntermediateDirectories: true, attributes: nil)

        for artName in artNames {
            let destination = artDirectory.appendingPathComponent(artName)
            guard !fileManager.fileExists(atPath: destination.path) else {
                continue
            }

            let source = bundledArtDirectory.appendingPathComponent(artName)
            guard fileManager.fileExists(atPath: source.path) else {
                continue
            }

            try fileManager.copyItem(at: source, to: destination)
        }
    }

    private func seedJSONPlugin(id: String, resourceName: String, fileManager: FileManager) throws {
        let pluginFolder = AppPaths.pluginsDirectory.appendingPathComponent(id, isDirectory: true)
        let manifestURL = pluginFolder.appendingPathComponent("plugin.json")
        guard !fileManager.fileExists(atPath: manifestURL.path) else {
            return
        }

        try fileManager.createDirectory(at: pluginFolder, withIntermediateDirectories: true, attributes: nil)
        let source = Bundle.module.url(forResource: resourceName, withExtension: "json")!
        try fileManager.copyItem(at: source, to: manifestURL)
    }

    private func seedBundledPluginFolder(id: String, fileManager: FileManager) throws {
        let pluginFolder = AppPaths.pluginsDirectory.appendingPathComponent(id, isDirectory: true)
        let manifestURL = pluginFolder.appendingPathComponent("plugin.json")
        guard !fileManager.fileExists(atPath: manifestURL.path) else {
            return
        }

        guard let bundledFolder = bundledPluginDirectory(id: id) else {
            return
        }

        try copyPluginFolder(from: bundledFolder, to: pluginFolder, fileManager: fileManager)
    }

    private func bundledPluginDirectory(id: String) -> URL? {
        guard let resourceRoot = Bundle.module.resourceURL else {
            return nil
        }

        let candidates = [
            resourceRoot.appendingPathComponent("Plugins", isDirectory: true).appendingPathComponent(id, isDirectory: true),
            resourceRoot.appendingPathComponent("plugins", isDirectory: true).appendingPathComponent(id, isDirectory: true),
        ]

        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func copyPluginFolder(from source: URL, to destination: URL, fileManager: FileManager) throws {
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        try fileManager.copyItem(at: source, to: destination)
    }
}

enum PluginStoreError: LocalizedError {
    case pluginNotFound(String)

    var errorDescription: String? {
        switch self {
        case .pluginNotFound(let id):
            return "Plugin not found: \(id)"
        }
    }
}
