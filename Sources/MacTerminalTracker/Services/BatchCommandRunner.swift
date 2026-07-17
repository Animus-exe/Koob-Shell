import Foundation

struct BatchCommandResult: Sendable {
    var command: String
    var output: String
    var exitCode: Int32
}

enum BatchCommandRunner {
    static func run(
        commands: [BatchCommand],
        shell: String = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh",
        workingDirectory: URL? = nil,
        environment: [String: String] = [:],
        outputHandler: @Sendable (String) -> Void
    ) async -> [BatchCommandResult] {
        var results: [BatchCommandResult] = []

        for command in commands {
            outputHandler("\n$ \(command.command)\n")
            let result = await runSingleCommand(
                command.command,
                shell: shell,
                workingDirectory: workingDirectory,
                environment: environment
            )
            outputHandler(result.output)
            outputHandler("exit \(result.exitCode)\n")
            results.append(result)

            if result.exitCode != 0 {
                outputHandler("Batch stopped on line \(command.lineNumber).\n")
                break
            }
        }

        return results
    }

    static func runSingleCommand(
        _ command: String,
        shell: String = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh",
        workingDirectory: URL? = nil,
        environment: [String: String] = [:]
    ) async -> BatchCommandResult {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: shell)
            process.arguments = ["-lc", command]
            process.currentDirectoryURL = workingDirectory
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                Task.detached {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    let output = String(decoding: data, as: UTF8.self)
                    continuation.resume(
                        returning: BatchCommandResult(
                            command: command,
                            output: output,
                            exitCode: process.terminationStatus
                        )
                    )
                }
            } catch {
                continuation.resume(
                    returning: BatchCommandResult(
                        command: command,
                        output: error.localizedDescription + "\n",
                        exitCode: 1
                    )
                )
            }
        }
    }
}
