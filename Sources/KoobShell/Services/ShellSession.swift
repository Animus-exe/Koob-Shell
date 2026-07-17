import Darwin
import Foundation

final class ShellSession: @unchecked Sendable {
    struct OutputChunk: Sendable {
        let text: String
    }

    private var process: Process?
    private var masterReadHandle: FileHandle?
    private var masterWriteHandle: FileHandle?
    private var masterFileDescriptor: Int32?
    private var isRunning = false
    var onOutput: (@Sendable (OutputChunk) -> Void)?
    var onExit: (@Sendable (Int32) -> Void)?

    func start(theme: ThemeDefinition) throws {
        stop()

        var masterFD: Int32 = 0
        var slaveFD: Int32 = 0
        guard openpty(&masterFD, &slaveFD, nil, nil, nil) == 0 else {
            throw POSIXError(.EIO)
        }

        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-l"]
        process.environment = shellEnvironment()

        let stdinFD = dup(slaveFD)
        let stdoutFD = dup(slaveFD)
        let stderrFD = dup(slaveFD)

        process.standardInput = FileHandle(fileDescriptor: stdinFD, closeOnDealloc: true)
        process.standardOutput = FileHandle(fileDescriptor: stdoutFD, closeOnDealloc: true)
        process.standardError = FileHandle(fileDescriptor: stderrFD, closeOnDealloc: true)

        let reader = FileHandle(fileDescriptor: masterFD, closeOnDealloc: true)
        let writer = FileHandle(fileDescriptor: dup(masterFD), closeOnDealloc: true)
        masterReadHandle = reader
        masterWriteHandle = writer
        masterFileDescriptor = masterFD

        reader.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let text = String(decoding: data, as: UTF8.self)
            self?.onOutput?(OutputChunk(text: text))
        }

        process.terminationHandler = { [weak self] finishedProcess in
            self?.isRunning = false
            self?.masterReadHandle?.readabilityHandler = nil
            self?.onExit?(finishedProcess.terminationStatus)
        }

        self.process = process
        try process.run()
        close(slaveFD)
        isRunning = true

        let banner = theme.renderedBanner()
        if !banner.isEmpty {
            onOutput?(OutputChunk(text: banner + "\n\n"))
        }
    }

    func send(_ raw: String) {
        guard isRunning, let writer = masterWriteHandle else { return }
        let payload = raw.hasSuffix("\n") ? raw : raw + "\n"
        writer.write(Data(payload.utf8))
    }

    func sendRaw(_ raw: String) {
        guard isRunning, let writer = masterWriteHandle else { return }
        writer.write(Data(raw.utf8))
    }

    func resize(columns: Int, rows: Int) {
        guard columns > 0, rows > 0, let masterFileDescriptor else { return }
        var windowSize = winsize(
            ws_row: UInt16(rows),
            ws_col: UInt16(columns),
            ws_xpixel: 0,
            ws_ypixel: 0
        )
        _ = ioctl(masterFileDescriptor, TIOCSWINSZ, &windowSize)
    }

    func stop() {
        guard let process else { return }
        process.interrupt()
        if process.isRunning {
            process.terminate()
        }
        masterReadHandle?.readabilityHandler = nil
        masterReadHandle = nil
        masterWriteHandle = nil
        masterFileDescriptor = nil
        self.process = nil
        isRunning = false
    }

    private func shellEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let existingPath = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = "\(AppPaths.binDirectory.path):\(existingPath)"
        environment["TERM"] = "xterm-256color"
        environment["COLORTERM"] = "truecolor"
        environment["TERM_PROGRAM"] = AppPaths.appName
        environment["TERM_PROGRAM_VERSION"] = "0.001.0"
        environment["TERM_SESSION_ID"] = UUID().uuidString
        environment["CLICOLOR"] = "1"

        if environment["LANG"]?.isEmpty != false {
            let identifier = Locale.autoupdatingCurrent.identifier.replacingOccurrences(of: "-", with: "_")
            environment["LANG"] = identifier.contains(".") ? identifier : "\(identifier).UTF-8"
        }
        if environment["LC_CTYPE"]?.isEmpty != false {
            environment["LC_CTYPE"] = environment["LANG"]
        }

        return environment
    }
}
