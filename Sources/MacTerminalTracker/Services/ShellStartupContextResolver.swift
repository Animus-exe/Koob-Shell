import Foundation

enum ShellStartupContextResolver {
    static func resolve(
        preferredDirectory: String? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        currentDirectoryPath: String = FileManager.default.currentDirectoryPath,
        homeDirectory: String = NSHomeDirectory(),
        fileManager: FileManager = .default
    ) -> String {
        for candidate in [preferredDirectory, environment["PWD"], currentDirectoryPath, homeDirectory] {
            guard let candidate else { continue }
            if isUsableDirectory(candidate, fileManager: fileManager) {
                return URL(fileURLWithPath: candidate, isDirectory: true).standardizedFileURL.path
            }
        }

        return homeDirectory
    }

    private static func isUsableDirectory(_ path: String, fileManager: FileManager) -> Bool {
        guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
