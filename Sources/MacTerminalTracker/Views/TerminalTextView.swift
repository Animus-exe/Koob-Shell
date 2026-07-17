import AppKit
import SwiftTerm
import SwiftUI

struct TerminalTextView: NSViewRepresentable {
    let theme: ThemeDefinition
    let appearance: AppearanceConfig
    let border: ShellBorderStyle
    let titleBar: ShellBorderStyle
    let terminalTitle: String
    let currentWorkingDirectory: String?
    let workflowSessionID: String
    let workflowShellEnvironment: [String: String]
    let useWorkflowShellOverlay: Bool
    let isSelected: Bool
    let focusToken: Int
    let onReady: @MainActor @Sendable () -> Void
    let onStartFailure: @MainActor @Sendable (String) -> Void
    let onActivity: @MainActor @Sendable () -> Void
    let onExit: @MainActor @Sendable (Int32?) -> Void
    let onTitleChange: @MainActor @Sendable (String) -> Void
    let onDirectoryChange: @MainActor @Sendable (String?) -> Void
    let onOpenPreferences: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onActivity: onActivity,
            onExit: onExit,
            onTitleChange: onTitleChange,
            onDirectoryChange: onDirectoryChange
        )
    }

    func makeNSView(context: Context) -> TerminalHostView {
        let view = TerminalHostView()
        view.update(
            theme: theme,
            appearance: appearance,
            border: border,
            titleBar: titleBar,
            terminalTitle: terminalTitle,
            currentWorkingDirectory: currentWorkingDirectory,
            workflowSessionID: workflowSessionID,
            workflowShellEnvironment: workflowShellEnvironment,
            useWorkflowShellOverlay: useWorkflowShellOverlay,
            isSelected: isSelected,
            focusToken: focusToken,
            coordinator: context.coordinator,
            onReady: onReady,
            onStartFailure: onStartFailure,
            onOpenPreferences: onOpenPreferences
        )
        return view
    }

    func updateNSView(_ nsView: TerminalHostView, context: Context) {
        context.coordinator.onActivity = onActivity
        context.coordinator.onExit = onExit
        context.coordinator.onTitleChange = onTitleChange
        context.coordinator.onDirectoryChange = onDirectoryChange
        nsView.update(
            theme: theme,
            appearance: appearance,
            border: border,
            titleBar: titleBar,
            terminalTitle: terminalTitle,
            currentWorkingDirectory: currentWorkingDirectory,
            workflowSessionID: workflowSessionID,
            workflowShellEnvironment: workflowShellEnvironment,
            useWorkflowShellOverlay: useWorkflowShellOverlay,
            isSelected: isSelected,
            focusToken: focusToken,
            coordinator: context.coordinator,
            onReady: onReady,
            onStartFailure: onStartFailure,
            onOpenPreferences: onOpenPreferences
        )
    }

    final class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        var onActivity: @MainActor @Sendable () -> Void
        var onExit: @MainActor @Sendable (Int32?) -> Void
        var onTitleChange: @MainActor @Sendable (String) -> Void
        var onDirectoryChange: @MainActor @Sendable (String?) -> Void

        init(
            onActivity: @escaping @MainActor @Sendable () -> Void,
            onExit: @escaping @MainActor @Sendable (Int32?) -> Void,
            onTitleChange: @escaping @MainActor @Sendable (String) -> Void,
            onDirectoryChange: @escaping @MainActor @Sendable (String?) -> Void
        ) {
            self.onActivity = onActivity
            self.onExit = onExit
            self.onTitleChange = onTitleChange
            self.onDirectoryChange = onDirectoryChange
        }

        nonisolated func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

        nonisolated func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            let onTitleChange = self.onTitleChange
            Task { @MainActor in
                onTitleChange(title)
            }
        }

        nonisolated func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            let onDirectoryChange = self.onDirectoryChange
            Task { @MainActor in
                onDirectoryChange(directory)
            }
        }

        nonisolated func processTerminated(source: TerminalView, exitCode: Int32?) {
            let onExit = self.onExit
            Task { @MainActor in
                onExit(exitCode)
            }
        }
    }
}

final class TerminalHostView: NSView {
    private let terminalSurfaceView = NSView()
    private let terminalView = TrackerTerminalView(frame: .zero)

    private var didStartProcess = false
    private var didConfigureScrollback = false
    private var lastThemeID = ""
    private var lastAppearance = AppearanceConfig.fallback
    private var lastBorder = ShellBorderStyle.defaultBorder
    private var lastTitleBar = ShellBorderStyle.defaultBorder
    private var lastTerminalTitle = AppPaths.displayName
    private var lastWorkingDirectory: String?
    private var lastFocusToken = -1
    private var isSelected = false
    private var terminalInset = CGFloat(ThemeDefinition.fallback.terminalPadding)

    var trackerTerminalView: TrackerTerminalView {
        terminalView
    }

    override var isOpaque: Bool {
        false
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        terminalSurfaceView.wantsLayer = true
        addSubview(terminalSurfaceView)

        terminalView.translatesAutoresizingMaskIntoConstraints = false
        terminalSurfaceView.addSubview(terminalView)

        NSLayoutConstraint.activate([
            terminalView.leadingAnchor.constraint(equalTo: terminalSurfaceView.leadingAnchor),
            terminalView.trailingAnchor.constraint(equalTo: terminalSurfaceView.trailingAnchor),
            terminalView.topAnchor.constraint(equalTo: terminalSurfaceView.topAnchor),
            terminalView.bottomAnchor.constraint(equalTo: terminalSurfaceView.bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        terminalSurfaceView.frame = bounds.insetBy(dx: terminalInset, dy: terminalInset)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureWindowIfNeeded()
        if isSelected {
            becomeActiveTerminal()
        }
    }

    func update(
        theme: ThemeDefinition,
        appearance: AppearanceConfig,
        border: ShellBorderStyle,
        titleBar: ShellBorderStyle,
        terminalTitle: String,
        currentWorkingDirectory: String?,
        workflowSessionID: String,
        workflowShellEnvironment: [String: String],
        useWorkflowShellOverlay: Bool,
        isSelected: Bool,
        focusToken: Int,
        coordinator: TerminalTextView.Coordinator,
        onReady: @escaping () -> Void,
        onStartFailure: @escaping (String) -> Void,
        onOpenPreferences: @escaping () -> Void
    ) {
        self.isSelected = isSelected
        terminalView.processDelegate = coordinator
        terminalView.activityHandler = coordinator.onActivity
        terminalView.preferencesHandler = onOpenPreferences
        terminalView.configure(
            theme: theme,
            appearance: appearance,
            border: border,
            workflowSessionID: workflowSessionID,
            workflowShellEnvironment: workflowShellEnvironment,
            useWorkflowShellOverlay: useWorkflowShellOverlay
        )
        terminalInset = CGFloat(max(theme.terminalPadding, 0))
        applyChrome(theme: theme, appearance: appearance, border: border)

        if isSelected {
            applyWindowChrome(border: border, titleBar: titleBar)
            applyWindowMetadata(title: terminalTitle, currentWorkingDirectory: currentWorkingDirectory)
            becomeActiveTerminal()
            if focusToken != lastFocusToken {
                lastFocusToken = focusToken
                DispatchQueue.main.async { [weak self] in
                    self?.focusTerminal()
                }
            }
        }

        if !didStartProcess {
            switch terminalView.startShellIfNeeded(currentWorkingDirectory: currentWorkingDirectory) {
            case .started:
                didStartProcess = true
                configureScrollbackIfNeeded()
                onReady()
            case .failed(let reason):
                didStartProcess = true
                onStartFailure(reason)
            case .alreadyStarted:
                didStartProcess = true
                configureScrollbackIfNeeded()
            }
        } else if lastThemeID != theme.id || lastAppearance != appearance || lastBorder != border || lastTitleBar != titleBar {
            terminalView.needsDisplay = true
        }

        lastThemeID = theme.id
        lastAppearance = appearance
        lastBorder = border
        lastTitleBar = titleBar
        lastTerminalTitle = terminalTitle
        lastWorkingDirectory = currentWorkingDirectory
    }

    private func configureScrollbackIfNeeded() {
        guard !didConfigureScrollback, terminalView.terminal != nil else { return }
        terminalView.getTerminal().changeScrollback(TerminalDefaults.scrollbackLines)
        didConfigureScrollback = true
    }

    private func becomeActiveTerminal() {
        ActiveTerminalRegistry.setCurrent(terminalView)
    }

    private func focusTerminal() {
        guard isSelected, let window else { return }
        window.makeFirstResponder(terminalView)
        ActiveTerminalRegistry.setCurrent(terminalView)
    }

    private func configureWindowIfNeeded() {
        guard let window else { return }
        NSWindow.allowsAutomaticWindowTabbing = false
        window.setFrameAutosaveName(AppPaths.appName)
        window.titleVisibility = .visible
        window.tabbingMode = .disallowed
        if isSelected {
            applyWindowChrome(border: lastBorder, titleBar: lastTitleBar)
            applyWindowMetadata(title: lastTerminalTitle, currentWorkingDirectory: lastWorkingDirectory)
        }
    }

    private func applyWindowChrome(border: ShellBorderStyle, titleBar: ShellBorderStyle) {
        WindowChromeConfigurator.apply(to: window, titleBar: titleBar, border: border)
    }

    private func applyChrome(theme: ThemeDefinition, appearance: AppearanceConfig, border: ShellBorderStyle) {
        applyShellTheme(theme: theme, appearance: appearance, border: border)
        terminalSurfaceView.layer?.cornerRadius = 10
        terminalSurfaceView.layer?.cornerCurve = .continuous
        terminalSurfaceView.layer?.shadowColor = NSColor.black.cgColor
        terminalSurfaceView.layer?.shadowOpacity = 0.08
        terminalSurfaceView.layer?.shadowRadius = 12
        terminalSurfaceView.layer?.shadowOffset = NSSize(width: 0, height: -2)
        terminalSurfaceView.layer?.masksToBounds = false
        needsLayout = true
    }

    private func applyShellTheme(theme: ThemeDefinition, appearance: AppearanceConfig, border: ShellBorderStyle) {
        let themeBackground = NSColor(hex: theme.backgroundColor) ?? .textBackgroundColor
        let shellOpacity = CGFloat(border.opacity.clamped(to: 0 ... 1))
        let terminalAlpha = CGFloat(appearance.terminalOpacity.clamped(to: 0 ... 1))

        terminalSurfaceView.layer?.backgroundColor = themeBackground.withAlphaComponent(terminalAlpha).cgColor

        if border.usesCustomShellChrome {
            let primary = resolvedShellColor(hex: border.primaryColor) ?? themeBackground
            terminalSurfaceView.layer?.borderWidth = 1
            terminalSurfaceView.layer?.borderColor = primary.withAlphaComponent(shellOpacity).cgColor
            return
        }

        terminalSurfaceView.layer?.borderWidth = 1
        terminalSurfaceView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
    }

    private func resolvedShellColor(hex: String?) -> NSColor? {
        guard let hex else { return nil }
        return NSColor(hex: hex)
    }

    private func applyWindowMetadata(title: String, currentWorkingDirectory: String?) {
        guard let window else { return }
        let resolvedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppPaths.displayName : title
        window.title = resolvedTitle

        if let currentWorkingDirectory, !currentWorkingDirectory.isEmpty {
            let directoryURL = URL(fileURLWithPath: currentWorkingDirectory, isDirectory: true)
            window.representedURL = directoryURL
            window.subtitle = (directoryURL.path as NSString).abbreviatingWithTildeInPath
        } else {
            window.representedURL = nil
            window.subtitle = ""
        }
    }
}

final class TrackerTerminalView: LocalProcessTerminalView, NSMenuItemValidation {
    enum ShellStartOutcome {
        case started
        case failed(String)
        case alreadyStarted
    }

    var activityHandler: (@MainActor @Sendable () -> Void)?
    var preferencesHandler: (() -> Void)?

    private var shellStarted = false
    private var workflowSessionID = UUID().uuidString
    private var workflowShellEnvironment: [String: String] = [:]
    private var useWorkflowShellOverlay = false

    override var isOpaque: Bool {
        false
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        configureBehavior()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureBehavior()
    }

    func configure(
        theme: ThemeDefinition,
        appearance: AppearanceConfig,
        border: ShellBorderStyle,
        workflowSessionID: String,
        workflowShellEnvironment: [String: String],
        useWorkflowShellOverlay: Bool
    ) {
        self.workflowSessionID = workflowSessionID
        self.workflowShellEnvironment = workflowShellEnvironment
        self.useWorkflowShellOverlay = useWorkflowShellOverlay

        let foregroundColor = NSColor(hex: theme.foregroundColor) ?? .textColor
        let backgroundColor = NSColor(hex: theme.backgroundColor) ?? .textBackgroundColor
        let accentColor = NSColor(hex: theme.accentColor) ?? .controlAccentColor

        font = NSFont(name: theme.fontName, size: theme.fontSize) ?? .monospacedSystemFont(ofSize: theme.fontSize, weight: .regular)
        nativeForegroundColor = foregroundColor
        nativeBackgroundColor = backgroundColor.withAlphaComponent(appearance.terminalOpacity)
        layer?.backgroundColor = nativeBackgroundColor.cgColor
        caretColor = accentColor
        selectedTextBackgroundColor = accentColor.withAlphaComponent(0.28)
        layer?.cornerRadius = 10
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
    }

    func startShellIfNeeded(currentWorkingDirectory: String?) -> ShellStartOutcome {
        guard !shellStarted else { return .alreadyStarted }
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        guard FileManager.default.isExecutableFile(atPath: shell) else {
            return .failed("Shell launch failed: \(shell) is not executable.")
        }

        let shellName = (shell as NSString).lastPathComponent
        var args = ["-l"]
        if useWorkflowShellOverlay, shellName == "bash" {
            args = ["-l", "--rcfile", AppPaths.bashOverlayRCURL.path]
        }

        let startupDirectory = ShellStartupContextResolver.resolve(
            preferredDirectory: currentWorkingDirectory
        )

        startProcess(
            executable: shell,
            args: args,
            environment: shellEnvironment(),
            execName: shellName,
            currentDirectory: startupDirectory
        )

        guard process.running else {
            return .failed("Shell launch failed: unable to start \(shellName) in \(startupDirectory).")
        }

        shellStarted = true
        return .started
    }

    override func dataReceived(slice: ArraySlice<UInt8>) {
        if let activityHandler {
            Task { @MainActor in
                activityHandler()
            }
        }
        super.dataReceived(slice: slice)
    }

    override func send(source: TerminalView, data: ArraySlice<UInt8>) {
        if let activityHandler {
            Task { @MainActor in
                activityHandler()
            }
        }
        super.send(source: source, data: data)
    }

    @objc
    public override func paste(_ sender: Any) {
        let pasteboard = NSPasteboard.general
        let original = pasteboard.string(forType: .string) ?? ""
        let normalized = PasteTextNormalizer.normalizeLineEndings(original)

        if PasteTextNormalizer.requiresConfirmation(normalized) {
            let lines = PasteTextNormalizer.lineCount(normalized)
            let alert = NSAlert()
            alert.messageText = "Paste \(lines) lines?"
            alert.informativeText = "The clipboard contains multiple lines. Paste them into the terminal?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Paste")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        if normalized != original {
            pasteboard.clearContents()
            pasteboard.setString(normalized, forType: .string)
            super.paste(sender)
            pasteboard.clearContents()
            pasteboard.setString(original, forType: .string)
        } else {
            super.paste(sender)
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()

        let copyItem = NSMenuItem(title: "Copy", action: #selector(copy(_:)), keyEquivalent: "")
        copyItem.target = self
        copyItem.isEnabled = selectionActive
        menu.addItem(copyItem)

        let pasteItem = NSMenuItem(title: "Paste", action: #selector(paste(_:)), keyEquivalent: "")
        pasteItem.target = self
        menu.addItem(pasteItem)

        let selectAllItem = NSMenuItem(title: "Select All", action: #selector(selectAll(_:)), keyEquivalent: "")
        selectAllItem.target = self
        menu.addItem(selectAllItem)

        menu.addItem(.separator())

        let findItem = NSMenuItem(title: "Find…", action: #selector(showFindPanel(_:)), keyEquivalent: "")
        findItem.target = self
        menu.addItem(findItem)

        menu.addItem(.separator())

        let preferencesItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences(_:)), keyEquivalent: "")
        preferencesItem.target = self
        menu.addItem(preferencesItem)

        return menu
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(copy(_:)):
            return selectionActive
        case #selector(selectAll(_:)):
            return true
        case #selector(paste(_:)):
            return true
        case #selector(showFindPanel(_:)):
            return true
        case #selector(openPreferences(_:)):
            return true
        default:
            return true
        }
    }

    @objc
    private func showFindPanel(_ sender: Any?) {
        let item = NSMenuItem()
        item.tag = Int(NSFindPanelAction.showFindPanel.rawValue)
        performFindPanelAction(item)
    }

    @objc
    private func openPreferences(_ sender: Any?) {
        preferencesHandler?()
    }

    private func configureBehavior() {
        optionAsMetaKey = false
        allowMouseReporting = true
        backspaceSendsControlH = false
    }

    private func shellEnvironment() -> [String] {
        var environment = ProcessInfo.processInfo.environment
        let existingPath = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = "\(AppPaths.binDirectory.path):\(existingPath)"
        environment["TERM"] = "xterm-256color"
        environment["COLORTERM"] = "truecolor"
        environment["TERM_PROGRAM"] = AppPaths.appName
        environment["TERM_PROGRAM_VERSION"] = "1.0"
        environment["TERM_SESSION_ID"] = workflowSessionID
        environment["CLICOLOR"] = "1"

        for (key, value) in workflowShellEnvironment {
            environment[key] = value
        }

        if useWorkflowShellOverlay {
            environment["ZDOTDIR"] = AppPaths.zdotdirOverlayDirectory.path
        }

        if environment["LANG"]?.isEmpty != false {
            environment["LANG"] = Self.fallbackLocaleIdentifier
        }
        if environment["LC_CTYPE"]?.isEmpty != false {
            environment["LC_CTYPE"] = environment["LANG"]
        }

        return environment
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
    }

    private static var fallbackLocaleIdentifier: String {
        let identifier = Locale.autoupdatingCurrent.identifier.replacingOccurrences(of: "-", with: "_")
        return identifier.contains(".") ? identifier : "\(identifier).UTF-8"
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
