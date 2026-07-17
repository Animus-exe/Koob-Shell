import Foundation

enum DestructiveCommandClassifier {
    struct Classification: Equatable, Sendable {
        var riskLevel: CommandRiskLevel
        var warning: String?
    }

    private static let riskRank: [CommandRiskLevel: Int] = [
        .safe: 0,
        .low: 1,
        .medium: 2,
        .high: 3,
        .destructive: 4,
    ]

    static func classify(_ command: String, rules: DestructiveCommandRules) -> Classification {
        var best = Classification(riskLevel: .low, warning: nil)
        var bestRank = -1

        for pattern in rules.patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern.regex, options: [.caseInsensitive]) else {
                continue
            }
            let range = NSRange(command.startIndex..<command.endIndex, in: command)
            guard regex.firstMatch(in: command, options: [], range: range) != nil else {
                continue
            }

            let rank = riskRank[pattern.risk] ?? 1
            if rank > bestRank {
                bestRank = rank
                best = Classification(riskLevel: pattern.risk, warning: pattern.warning)
            }
        }

        return best
    }
}
