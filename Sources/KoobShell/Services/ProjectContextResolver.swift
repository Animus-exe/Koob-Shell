import Foundation

enum ProjectContextResolver {
    struct ProjectContext: Equatable, Sendable {
        var root: String
        var name: String
    }

    static func resolve(workingDirectory: String) -> ProjectContext {
        let fileManager = FileManager.default
        var current = URL(fileURLWithPath: workingDirectory, isDirectory: true)

        while true {
            let gitPath = current.appendingPathComponent(".git")
            if fileManager.fileExists(atPath: gitPath.path) {
                return ProjectContext(root: current.path, name: current.lastPathComponent)
            }

            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                break
            }
            current = parent
        }

        let fallbackName = URL(fileURLWithPath: workingDirectory).lastPathComponent
        return ProjectContext(root: workingDirectory, name: fallbackName.isEmpty ? "unknown" : fallbackName)
    }
}
