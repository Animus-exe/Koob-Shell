import Foundation

enum PasteTextNormalizer {
    static let characterThreshold = 500

    static func normalizeLineEndings(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    static func lineCount(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        return text.reduce(into: 1) { count, character in
            if character == "\n" {
                count += 1
            }
        }
    }

    static func requiresConfirmation(_ text: String) -> Bool {
        lineCount(text) >= 2 || text.count >= characterThreshold
    }
}
