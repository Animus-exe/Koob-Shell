import Foundation
import Observation

@MainActor
@Observable
final class CommandStore {
    private(set) var commands: [CommandDefinition] = []
    var loadError: String?

    init() {
        reload()
    }

    func reload() {
        do {
            try ensureSupportFiles()
            let data = try Data(contentsOf: AppPaths.commandsURL)
            commands = try CommandsCodec.decode(from: data)
            loadError = nil
        } catch {
            commands = []
            loadError = "Command config fallback loaded: \(error.localizedDescription)"
        }
    }

    func save(_ commands: [CommandDefinition]) throws {
        let data = try CommandsCodec.encode(commands)
        try FileManager.default.createDirectory(at: AppPaths.appSupportDirectory, withIntermediateDirectories: true, attributes: nil)
        try data.write(to: AppPaths.commandsURL, options: .atomic)
        reload()
    }

    private func ensureSupportFiles() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: AppPaths.appSupportDirectory, withIntermediateDirectories: true, attributes: nil)

        if !fileManager.fileExists(atPath: AppPaths.commandsURL.path) {
            let source = Bundle.module.url(forResource: "default-commands", withExtension: "json")!
            try fileManager.copyItem(at: source, to: AppPaths.commandsURL)
        }
    }
}
