import Foundation

enum TrackedToolMatcher {
    static func isRunning(
        matchType: ToolMatchType,
        matchValue: String,
        appBundleIDs: Set<String>,
        appLocalizedNames: Set<String>,
        appExecutableNames: Set<String>,
        processNames: Set<String>
    ) -> Bool {
        let needle = matchValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return false }

        switch matchType {
        case .bundleIdentifier:
            return appBundleIDs.contains(needle)
        case .localizedName:
            return appLocalizedNames.contains(needle.lowercased())
        case .executableName:
            let executable = needle.lowercased()
            return appExecutableNames.contains(executable) || processNames.contains(executable)
        }
    }

    static func color(for displayName: String) -> String {
        let palette = [
            "#F97316", "#3B82F6", "#10B981", "#8B5CF6", "#EF4444",
            "#60A5FA", "#06B6D4", "#EC4899", "#EAB308", "#14B8A6",
        ]
        let hash = displayName.unicodeScalars.reduce(into: 0) { partial, scalar in
            partial = (partial &+ Int(scalar.value)) &+ 31
        }
        return palette[abs(hash) % palette.count]
    }

    static func matchType(fromCLIType type: String) -> ToolMatchType? {
        switch type.lowercased() {
        case "process", "executable", "exec":
            return .executableName
        case "app", "name", "application":
            return .localizedName
        case "bundle", "bundleid", "bundle-id":
            return .bundleIdentifier
        default:
            return nil
        }
    }

    static func cliType(for matchType: ToolMatchType) -> String {
        switch matchType {
        case .executableName:
            return "process"
        case .localizedName:
            return "app"
        case .bundleIdentifier:
            return "bundle"
        }
    }
}
