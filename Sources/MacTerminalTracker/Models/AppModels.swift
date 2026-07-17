import Foundation

enum CommandRunMode: String, Codable, CaseIterable, Sendable {
    case interactive
    case batch
}

struct CommandArgument: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var key: String
    var label: String
    var defaultValue: String = ""
    var required: Bool = false
}

struct CommandDefinition: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var name: String
    var template: String
    var arguments: [CommandArgument] = []
    var defaultWorkingDirectory: String?
    var environment: [String: String] = [:]
    var runMode: CommandRunMode = .interactive
}

enum BannerAlignment: String, Codable, CaseIterable, Sendable {
    case leading
    case center
    case trailing
}

struct ShellBorderStyle: Codable, Hashable, Sendable {
    var primaryColor: String?
    var secondaryColor: String?
    var opacity: Double
    var colorDepth: Double

    static let defaultBorder = ShellBorderStyle()

    init(
        primaryColor: String? = nil,
        secondaryColor: String? = nil,
        opacity: Double = 0.35,
        colorDepth: Double = 0.5
    ) {
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.opacity = opacity
        self.colorDepth = colorDepth
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        primaryColor = try container.decodeIfPresent(String.self, forKey: .primaryColor)
        secondaryColor = try container.decodeIfPresent(String.self, forKey: .secondaryColor)
        opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? Self.defaultBorder.opacity
        colorDepth = try container.decodeIfPresent(Double.self, forKey: .colorDepth) ?? Self.defaultBorder.colorDepth
    }

    var usesGradientBorder: Bool {
        guard let secondaryColor, !secondaryColor.isEmpty else {
            return false
        }
        return colorDepth > 0.01
    }

    var usesCustomShellChrome: Bool {
        if let primaryColor, !primaryColor.isEmpty {
            return true
        }
        return usesGradientBorder
    }

    func applying(_ overrides: AppearanceBorderOverrides) -> ShellBorderStyle {
        var border = self
        if let primaryColor = overrides.primaryColor {
            border.primaryColor = primaryColor
        }
        if let secondaryColor = overrides.secondaryColor {
            border.secondaryColor = secondaryColor.isEmpty ? nil : secondaryColor
        }
        if let opacity = overrides.opacity {
            border.opacity = opacity
        }
        if let colorDepth = overrides.colorDepth {
            border.colorDepth = colorDepth
        }
        return border
    }

    static func blendedHexColor(primary: String, secondary: String, depth: Double) -> String {
        let clampedDepth = min(max(depth, 0), 1)
        guard clampedDepth > 0 else {
            return primary
        }

        let primaryComponents = hexComponents(primary) ?? (0, 0, 0)
        let secondaryComponents = hexComponents(secondary) ?? primaryComponents

        let red = Int(round(Double(primaryComponents.0) + (Double(secondaryComponents.0) - Double(primaryComponents.0)) * clampedDepth))
        let green = Int(round(Double(primaryComponents.1) + (Double(secondaryComponents.1) - Double(primaryComponents.1)) * clampedDepth))
        let blue = Int(round(Double(primaryComponents.2) + (Double(secondaryComponents.2) - Double(primaryComponents.2)) * clampedDepth))

        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    private static func hexComponents(_ hex: String) -> (Int, Int, Int)? {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else {
            return nil
        }
        return ((value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF)
    }
}

struct ThemeDefinition: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var bannerEnabled: Bool
    var bannerText: String
    var bannerAlignment: BannerAlignment
    var promptLabel: String
    var foregroundColor: String
    var backgroundColor: String
    var accentColor: String
    var terminalPadding: Double
    var fontName: String
    var fontSize: Double
    var border: ShellBorderStyle?
    var titleBar: ShellBorderStyle?

    static let builtIn: [ThemeDefinition] = [
        ThemeDefinition(
            id: "midnight",
            name: "Graphite",
            bannerEnabled: true,
            bannerText: """
██╗  ██╗ ██████╗  ██████╗ ██████╗     ███████╗██╗  ██╗███████╗██╗     ██╗
██║ ██╔╝██╔═══██╗██╔═══██╗██╔══██╗    ██╔════╝██║  ██║██╔════╝██║     ██║
█████╔╝ ██║   ██║██║   ██║██████╔╝    ███████╗███████║█████╗  ██║     ██║
██╔═██╗ ██║   ██║██║   ██║██╔══██╗    ╚════██║██╔══██║██╔══╝  ██║     ██║
██║  ██╗╚██████╔╝╚██████╔╝██████╔╝    ███████║██║  ██║███████╗███████╗███████╗
╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚═════╝     ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝
""",
            bannerAlignment: .center,
            promptLabel: "koob",
            foregroundColor: "#E8E8E6",
            backgroundColor: "#171717",
            accentColor: "#91D462",
            terminalPadding: 10,
            fontName: "Menlo",
            fontSize: 13
        ),
        ThemeDefinition(
            id: "paper",
            name: "Paper",
            bannerEnabled: true,
            bannerText: """
 _  __            _       ____  _          _ _
| |/ /___   ___  | |__   / ___|| |__   ___| | |
| ' // _ \\ / _ \\ | '_ \\  \\___ \\| '_ \\ / _ \\ | |
| . \\ (_) | (_) || |_) |  ___) | | | |  __/ | |
|_|\\_\\___/ \\___/ |_.__/  |____/|_| |_|\\___|_|_|
""",
            bannerAlignment: .leading,
            promptLabel: "koob",
            foregroundColor: "#1F2937",
            backgroundColor: "#F9FAFB",
            accentColor: "#0F766E",
            terminalPadding: 10,
            fontName: "Menlo",
            fontSize: 13
        ),
        ThemeDefinition(
            id: "signal",
            name: "Signal",
            bannerEnabled: true,
            bannerText: """
██╗  ██╗ ██████╗  ██████╗ ██████╗
██║ ██╔╝██╔═══██╗██╔═══██╗██╔══██╗
█████╔╝ ██║   ██║██║   ██║██████╔╝
██╔═██╗ ██║   ██║██║   ██║██╔══██╗
██║  ██╗╚██████╔╝╚██████╔╝██████╔╝
╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚═════╝
""",
            bannerAlignment: .center,
            promptLabel: "ops",
            foregroundColor: "#D1FAE5",
            backgroundColor: "#052E16",
            accentColor: "#34D399",
            terminalPadding: 10,
            fontName: "Menlo",
            fontSize: 13
        ),
    ]

    static let fallback = ThemeDefinition.builtIn[0]

    func renderedBanner(width: Int = 72) -> String {
        guard bannerEnabled else { return "" }
        return bannerText
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { rawLine in
                let line = String(rawLine)
                let padding = max(width - line.count, 0)
                let prefix: String
                switch bannerAlignment {
                case .leading:
                    prefix = ""
                case .center:
                    prefix = String(repeating: " ", count: padding / 2)
                case .trailing:
                    prefix = String(repeating: " ", count: padding)
                }
                return prefix + line
            }
            .joined(separator: "\n")
    }

    func applying(_ overrides: AppearanceColorOverrides) -> ThemeDefinition {
        var theme = self
        if let foregroundColor = overrides.foregroundColor {
            theme.foregroundColor = foregroundColor
        }
        if let backgroundColor = overrides.backgroundColor {
            theme.backgroundColor = backgroundColor
        }
        if let accentColor = overrides.accentColor {
            theme.accentColor = accentColor
        }
        return theme
    }

    func resolvedBorder(applying overrides: AppearanceBorderOverrides = .empty) -> ShellBorderStyle {
        (border ?? .defaultBorder).applying(overrides)
    }

    func resolvedTitleBar(
        shellFallback: ShellBorderStyle,
        applying overrides: AppearanceBorderOverrides = .empty
    ) -> ShellBorderStyle {
        if overrides != .empty {
            let base = titleBar ?? border ?? .defaultBorder
            return base.applying(overrides)
        }

        if titleBar != nil {
            return titleBar!.applying(overrides)
        }

        return shellFallback
    }
}

struct AppearanceColorOverrides: Codable, Hashable, Sendable {
    var foregroundColor: String?
    var backgroundColor: String?
    var accentColor: String?

    static let empty = AppearanceColorOverrides()
}

struct AppearanceBorderOverrides: Codable, Hashable, Sendable {
    var primaryColor: String?
    var secondaryColor: String?
    var opacity: Double?
    var colorDepth: Double?

    static let empty = AppearanceBorderOverrides()
}

enum AppearanceColorOverrideKey: String, Hashable, Sendable {
    case foreground
    case background
    case accent
}

struct AppearanceConfig: Codable, Hashable, Sendable {
    static let galleryAutoRevealTerminalOpacity = 0.18
    static let minimumVisibleGalleryOpacity = 0.05
    static let defaultVisibleGalleryOpacity = 0.1
    static let maximumGalleryOpacity = 0.35
    static let defaultGalleryIntervalSeconds = 18.0
    static let minimumGalleryIntervalSeconds = 5.0
    static let maximumGalleryIntervalSeconds = 120.0

    var activeThemeID: String
    var allowPluginThemes: Bool
    var allowPluginGalleries: Bool
    var customThemes: [ThemeDefinition]
    var terminalOpacity: Double
    var galleryEnabled: Bool
    var galleryOpacity: Double
    var galleryTintColor: String
    var galleryFullScreen: Bool
    var galleryIntervalSeconds: Double
    var galleryRevolve: Bool
    var colorOverrides: AppearanceColorOverrides
    var borderOverrides: AppearanceBorderOverrides
    var titleBarOverrides: AppearanceBorderOverrides

    static let fallback = AppearanceConfig(
        activeThemeID: ThemeDefinition.fallback.id,
        allowPluginThemes: true,
        allowPluginGalleries: true,
        customThemes: [],
        terminalOpacity: 1,
        galleryEnabled: false,
        galleryOpacity: 0.04,
        galleryTintColor: "#D5D9DE",
        galleryFullScreen: true,
        galleryIntervalSeconds: defaultGalleryIntervalSeconds,
        galleryRevolve: true,
        colorOverrides: .empty,
        borderOverrides: .empty,
        titleBarOverrides: .empty
    )

    init(
        activeThemeID: String,
        allowPluginThemes: Bool,
        allowPluginGalleries: Bool = AppearanceConfig.fallback.allowPluginGalleries,
        customThemes: [ThemeDefinition],
        terminalOpacity: Double = AppearanceConfig.fallback.terminalOpacity,
        galleryEnabled: Bool = AppearanceConfig.fallback.galleryEnabled,
        galleryOpacity: Double = AppearanceConfig.fallback.galleryOpacity,
        galleryTintColor: String = AppearanceConfig.fallback.galleryTintColor,
        galleryFullScreen: Bool = AppearanceConfig.fallback.galleryFullScreen,
        galleryIntervalSeconds: Double = AppearanceConfig.fallback.galleryIntervalSeconds,
        galleryRevolve: Bool = AppearanceConfig.fallback.galleryRevolve,
        colorOverrides: AppearanceColorOverrides = .empty,
        borderOverrides: AppearanceBorderOverrides = .empty,
        titleBarOverrides: AppearanceBorderOverrides = .empty
    ) {
        self.activeThemeID = activeThemeID
        self.allowPluginThemes = allowPluginThemes
        self.allowPluginGalleries = allowPluginGalleries
        self.customThemes = customThemes
        self.terminalOpacity = terminalOpacity
        self.galleryEnabled = galleryEnabled
        self.galleryOpacity = galleryOpacity
        self.galleryTintColor = galleryTintColor
        self.galleryFullScreen = galleryFullScreen
        self.galleryIntervalSeconds = galleryIntervalSeconds
        self.galleryRevolve = galleryRevolve
        self.colorOverrides = colorOverrides
        self.borderOverrides = borderOverrides
        self.titleBarOverrides = titleBarOverrides
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        activeThemeID = try container.decodeIfPresent(String.self, forKey: .activeThemeID) ?? AppearanceConfig.fallback.activeThemeID
        allowPluginThemes = try container.decodeIfPresent(Bool.self, forKey: .allowPluginThemes) ?? AppearanceConfig.fallback.allowPluginThemes
        allowPluginGalleries = try container.decodeIfPresent(Bool.self, forKey: .allowPluginGalleries) ?? AppearanceConfig.fallback.allowPluginGalleries
        customThemes = try container.decodeIfPresent([ThemeDefinition].self, forKey: .customThemes) ?? AppearanceConfig.fallback.customThemes
        terminalOpacity = try container.decodeIfPresent(Double.self, forKey: .terminalOpacity) ?? AppearanceConfig.fallback.terminalOpacity
        galleryEnabled = try container.decodeIfPresent(Bool.self, forKey: .galleryEnabled) ?? AppearanceConfig.fallback.galleryEnabled
        galleryOpacity = try container.decodeIfPresent(Double.self, forKey: .galleryOpacity) ?? AppearanceConfig.fallback.galleryOpacity
        galleryTintColor = try container.decodeIfPresent(String.self, forKey: .galleryTintColor) ?? AppearanceConfig.fallback.galleryTintColor
        galleryFullScreen = try container.decodeIfPresent(Bool.self, forKey: .galleryFullScreen) ?? AppearanceConfig.fallback.galleryFullScreen
        galleryIntervalSeconds = try container.decodeIfPresent(Double.self, forKey: .galleryIntervalSeconds) ?? AppearanceConfig.fallback.galleryIntervalSeconds
        galleryRevolve = try container.decodeIfPresent(Bool.self, forKey: .galleryRevolve) ?? AppearanceConfig.fallback.galleryRevolve
        colorOverrides = try container.decodeIfPresent(AppearanceColorOverrides.self, forKey: .colorOverrides) ?? .empty
        borderOverrides = try container.decodeIfPresent(AppearanceBorderOverrides.self, forKey: .borderOverrides) ?? .empty
        titleBarOverrides = try container.decodeIfPresent(AppearanceBorderOverrides.self, forKey: .titleBarOverrides) ?? .empty
        normalizeGallerySettings()
    }

    mutating func normalizeGallerySettings() {
        guard galleryEnabled else {
            return
        }

        if galleryOpacity < Self.minimumVisibleGalleryOpacity {
            galleryOpacity = Self.defaultVisibleGalleryOpacity
        }

        if terminalOpacity > Self.galleryAutoRevealTerminalOpacity {
            terminalOpacity = Self.galleryAutoRevealTerminalOpacity
        }

        galleryIntervalSeconds = min(
            max(galleryIntervalSeconds, Self.minimumGalleryIntervalSeconds),
            Self.maximumGalleryIntervalSeconds
        )
    }

    mutating func setGalleryEnabled(_ enabled: Bool) {
        galleryEnabled = enabled

        guard enabled else {
            return
        }

        normalizeGallerySettings()
    }
}

enum ToolMatchType: String, Codable, CaseIterable, Sendable {
    case bundleIdentifier
    case localizedName
    case executableName
}

struct TrackedTool: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var displayName: String
    var matchType: ToolMatchType
    var matchValue: String
    var color: String
    var isEnabled: Bool = true

    static let seeded: [TrackedTool] = [
        TrackedTool(displayName: "Cursor", matchType: .bundleIdentifier, matchValue: "com.todesktop.230313mzl4w4u92", color: "#F97316"),
        TrackedTool(displayName: "Visual Studio Code", matchType: .bundleIdentifier, matchValue: "com.microsoft.VSCode", color: "#3B82F6"),
        TrackedTool(displayName: "Terminal", matchType: .bundleIdentifier, matchValue: "com.apple.Terminal", color: "#10B981"),
        TrackedTool(displayName: "iTerm", matchType: .bundleIdentifier, matchValue: "com.googlecode.iterm2", color: "#8B5CF6"),
        TrackedTool(displayName: "Warp", matchType: .bundleIdentifier, matchValue: "dev.warp.Warp-Stable", color: "#EF4444"),
        TrackedTool(displayName: "Xcode", matchType: .bundleIdentifier, matchValue: "com.apple.dt.Xcode", color: "#60A5FA"),
        TrackedTool(displayName: "Docker Desktop", matchType: .bundleIdentifier, matchValue: "com.docker.docker", color: "#06B6D4"),
    ]
}

struct ToolUsageSummary: Identifiable, Hashable, Sendable {
    var id: UUID
    var displayName: String
    var color: String
    var todayMinutes: Int
    var totalMinutes: Int
    var isRunning: Bool

    var todayHoursString: String {
        Self.format(minutes: todayMinutes)
    }

    var totalHoursString: String {
        Self.format(minutes: totalMinutes)
    }

    static func format(minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 {
            return "\(remainder)m"
        }
        return "\(hours)h \(remainder)m"
    }
}

struct BatchCommand: Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var lineNumber: Int
    var command: String
}

enum CatalogSourceKind: String, Codable, CaseIterable, Sendable {
    case builtIn
    case user
    case plugin
}

struct ThemeCatalogItem: Identifiable, Hashable, Sendable {
    var id: String { "\(sourceKind.rawValue):\(theme.id)" }
    var theme: ThemeDefinition
    var sourceName: String
    var sourceKind: CatalogSourceKind
}

struct CommandCatalogEntry: Identifiable, Hashable, Sendable {
    var id: UUID { command.id }
    var command: CommandDefinition
    var sourceName: String
    var sourceKind: CatalogSourceKind
}

struct PluginGalleryDefinition: Codable, Hashable, Sendable {
    var artDirectory: String

    static let fallback = PluginGalleryDefinition(artDirectory: "Ascii_art")
}

enum DestructiveWarningMode: String, Codable, CaseIterable, Sendable {
    case off
    case warn
    case confirm
}

struct WorkflowShellIntegration: Codable, Hashable, Sendable {
    var envFlag: String
    var sessionEnvVar: String
    var zshHook: String
    var bashHook: String

    static let `default` = WorkflowShellIntegration(
        envFlag: "KOOBSHELL_INTEGRATION",
        sessionEnvVar: "KOOBSHELL_SESSION_ID",
        zshHook: "shell/koobshell.zsh",
        bashHook: "shell/koobshell.bash"
    )
}

struct WorkflowPreferences: Codable, Hashable, Sendable {
    var captureEnabled: Bool
    var destructiveWarnings: DestructiveWarningMode
    var autoSummaryOnExit: Bool

    static let `default` = WorkflowPreferences(
        captureEnabled: true,
        destructiveWarnings: .warn,
        autoSummaryOnExit: true
    )
}

struct WorkflowUIConfig: Codable, Hashable, Sendable {
    var inspectorPanelEnabled: Bool
    var defaultPanelWidth: Double

    static let `default` = WorkflowUIConfig(
        inspectorPanelEnabled: true,
        defaultPanelWidth: 320
    )
}

struct WorkflowPluginDefinition: Codable, Hashable, Sendable {
    var cliName: String
    var shellIntegration: WorkflowShellIntegration
    var rulesDirectory: String
    var preferences: WorkflowPreferences
    var ui: WorkflowUIConfig

    static let `default` = WorkflowPluginDefinition(
        cliName: "koobshell",
        shellIntegration: .default,
        rulesDirectory: "rules",
        preferences: .default,
        ui: .default
    )
}

enum CommandRiskLevel: String, Codable, CaseIterable, Sendable {
    case safe
    case low
    case medium
    case high
    case destructive
}

enum SessionOutcome: String, Codable, CaseIterable, Sendable {
    case success
    case failure
    case mixed
    case inProgress
}

struct WorkflowSession: Identifiable, Hashable, Sendable {
    var id: UUID
    var pluginID: String
    var projectRoot: String?
    var projectName: String?
    var detectedGoal: String?
    var outcome: SessionOutcome
    var startedAt: Date
    var endedAt: Date?
    var summaryText: String?
    var commands: [WorkflowCommand]
    var fileChanges: [WorkflowFileChange]
    var rollbackPlanJSON: String?
}

struct WorkflowCommand: Identifiable, Hashable, Sendable {
    var id: UUID
    var sessionID: UUID
    var sequence: Int
    var commandText: String
    var workingDirectory: String?
    var exitCode: Int32?
    var riskLevel: CommandRiskLevel
    var startedAt: Date
    var endedAt: Date?
    var durationMilliseconds: Int?
}

struct WorkflowFileChange: Identifiable, Hashable, Sendable {
    var id: UUID
    var sessionID: UUID
    var commandID: UUID?
    var path: String
    var changeKind: String
    var detectedAt: Date
}

struct DestructiveCommandPattern: Codable, Hashable, Sendable {
    var regex: String
    var risk: CommandRiskLevel
    var warning: String?
}

struct DestructiveCommandRules: Codable, Hashable, Sendable {
    var patterns: [DestructiveCommandPattern]
}

struct GoalPattern: Codable, Hashable, Sendable {
    var id: String
    var label: String
    var signals: [String]
    var requiresFailures: Bool?
}

struct GoalPatternRules: Codable, Hashable, Sendable {
    var goals: [GoalPattern]
}

struct RollbackTemplate: Codable, Hashable, Sendable {
    var changeKind: String?
    var afterCommand: String?
    var template: String
}

struct RollbackTemplateRules: Codable, Hashable, Sendable {
    var templates: [RollbackTemplate]
}

struct LoadedWorkflowRules: Hashable, Sendable {
    var destructive: DestructiveCommandRules
    var goals: GoalPatternRules
    var rollback: RollbackTemplateRules

    static let empty = LoadedWorkflowRules(
        destructive: DestructiveCommandRules(patterns: []),
        goals: GoalPatternRules(goals: []),
        rollback: RollbackTemplateRules(templates: [])
    )
}

struct GalleryCatalogItem: Identifiable, Hashable, Sendable {
    var id: String { pluginID }
    var pluginID: String
    var pluginName: String
    var entries: [AsciiArtEntry]
}

struct PluginManifest: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var version: String
    var isEnabled: Bool
    var commands: [CommandDefinition]
    var themes: [ThemeDefinition]
    var gallery: PluginGalleryDefinition?
    var workflow: WorkflowPluginDefinition?

    init(
        id: String,
        name: String,
        version: String,
        isEnabled: Bool,
        commands: [CommandDefinition],
        themes: [ThemeDefinition],
        gallery: PluginGalleryDefinition? = nil,
        workflow: WorkflowPluginDefinition? = nil
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.isEnabled = isEnabled
        self.commands = commands
        self.themes = themes
        self.gallery = gallery
        self.workflow = workflow
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        version = try container.decode(String.self, forKey: .version)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        commands = try container.decodeIfPresent([CommandDefinition].self, forKey: .commands) ?? []
        themes = try container.decodeIfPresent([ThemeDefinition].self, forKey: .themes) ?? []
        gallery = try container.decodeIfPresent(PluginGalleryDefinition.self, forKey: .gallery)
        workflow = try container.decodeIfPresent(WorkflowPluginDefinition.self, forKey: .workflow)
    }
}

struct LoadedPlugin: Identifiable, Hashable, Sendable {
    var id: String { manifest.id }
    var manifest: PluginManifest
    var manifestURL: URL

    var rootURL: URL {
        manifestURL.deletingLastPathComponent()
    }
}

enum BatchParser {
    static func parse(_ raw: String) -> [BatchCommand] {
        raw
            .components(separatedBy: .newlines)
            .enumerated()
            .compactMap { index, line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else {
                    return nil
                }
                return BatchCommand(lineNumber: index + 1, command: trimmed)
            }
    }
}

enum CommandTemplateRenderer {
    enum Error: LocalizedError, Equatable {
        case missingRequiredArgument(String)

        var errorDescription: String? {
            switch self {
            case .missingRequiredArgument(let key):
                return "Missing required argument: \(key)"
            }
        }
    }

    static func render(command: CommandDefinition, values: [String: String]) throws -> String {
        for argument in command.arguments where argument.required {
            let provided = values[argument.key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if provided.isEmpty {
                throw Error.missingRequiredArgument(argument.key)
            }
        }

        return command.arguments.reduce(command.template) { partial, argument in
            let fallback = argument.defaultValue
            let rawValue = values[argument.key]?.isEmpty == false ? values[argument.key]! : fallback
            let token = "{{\(argument.key)}}"
            return partial.replacingOccurrences(of: token, with: shellEscape(rawValue))
        }
    }

    static func preview(command: CommandDefinition, values: [String: String]) -> String {
        (try? render(command: command, values: values)) ?? command.template
    }

    private static func shellEscape(_ value: String) -> String {
        guard value.contains(where: { $0.isWhitespace || "'\"\\$".contains($0) }) else {
            return value
        }
        let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }
}

enum AppPaths {
    static let appName = "KoobShell"
    static let displayName = "Koob Shell"
    static let legacyAppNames = ["InKShell", "MacTerminalTracker", "OrcShell"]
    static let mainWindowIdentifier = "\(appName).Main"
    static let preferencesWindowIdentifier = "\(appName).Preferences"

    static var appSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent(appName, isDirectory: true)
    }

    static func migrateLegacyAppSupportIfNeeded() {
        let fileManager = FileManager.default
        let newDirectory = appSupportDirectory
        guard !fileManager.fileExists(atPath: newDirectory.path) else { return }

        guard let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }

        for legacyName in legacyAppNames {
            let legacyDirectory = base.appendingPathComponent(legacyName, isDirectory: true)
            guard fileManager.fileExists(atPath: legacyDirectory.path) else { continue }
            try? fileManager.moveItem(at: legacyDirectory, to: newDirectory)
            return
        }
    }

    static var commandsURL: URL {
        appSupportDirectory.appendingPathComponent("commands.json")
    }

    static var appearanceURL: URL {
        appSupportDirectory.appendingPathComponent("appearance.json")
    }

    static var pluginsDirectory: URL {
        appSupportDirectory.appendingPathComponent("plugins", isDirectory: true)
    }

    static var binDirectory: URL {
        appSupportDirectory.appendingPathComponent("bin", isDirectory: true)
    }

    static var databaseURL: URL {
        appSupportDirectory.appendingPathComponent("tracker.sqlite3")
    }

    static var trackerCommandURL: URL {
        binDirectory.appendingPathComponent("tracker")
    }

    static var nativeHelpCommandURL: URL {
        binDirectory.appendingPathComponent("-help")
    }

    static var shellDirectory: URL {
        appSupportDirectory.appendingPathComponent("shell", isDirectory: true)
    }

    static var zdotdirOverlayDirectory: URL {
        shellDirectory.appendingPathComponent("zdotdir", isDirectory: true)
    }

    static var bashOverlayRCURL: URL {
        shellDirectory.appendingPathComponent("koobshell.bashrc")
    }

    static var koobshellCommandURL: URL {
        binDirectory.appendingPathComponent("koobshell")
    }

    static func pluginSettingsURL(pluginID: String) -> URL {
        pluginsDirectory
            .appendingPathComponent(pluginID, isDirectory: true)
            .appendingPathComponent("plugin-settings.json")
    }
}

enum AppearanceCodec {
    static func decode(from data: Data) throws -> AppearanceConfig {
        try JSONDecoder().decode(AppearanceConfig.self, from: data)
    }

    static func encode(_ config: AppearanceConfig) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(config)
    }
}

enum CommandsCodec {
    static func decode(from data: Data) throws -> [CommandDefinition] {
        try JSONDecoder().decode([CommandDefinition].self, from: data)
    }

    static func encode(_ commands: [CommandDefinition]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(commands)
    }
}

enum PluginCodec {
    static func decode(from data: Data) throws -> PluginManifest {
        try JSONDecoder().decode(PluginManifest.self, from: data)
    }

    static func encode(_ plugin: PluginManifest) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(plugin)
    }
}
