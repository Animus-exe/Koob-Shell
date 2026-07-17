import Foundation

enum ProcessSnapshot {
    /// Lowercased executable basenames for currently running processes.
    static func runningExecutableNames(
        runner: (URL, [String]) throws -> String = runProcess
    ) -> Set<String> {
        let output: String
        do {
            output = try runner(URL(fileURLWithPath: "/bin/ps"), ["-axo", "comm="])
        } catch {
            return []
        }

        var names: Set<String> = []
        for line in output.split(whereSeparator: \.isNewline) {
            let path = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else { continue }
            names.insert((path as NSString).lastPathComponent.lowercased())
        }
        return names
    }

    private static func runProcess(executable: URL, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
