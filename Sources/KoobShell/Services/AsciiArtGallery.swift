import Foundation

enum AsciiArtGallery {
    static func rotatingIndex(at date: Date, count: Int, interval: TimeInterval = AppearanceConfig.defaultGalleryIntervalSeconds) -> Int {
        guard count > 0 else {
            return 0
        }

        let slotDuration = max(interval, 1)
        let slot = Int(floor(date.timeIntervalSinceReferenceDate / slotDuration))
        return positiveModulo(slot, count)
    }

    static func resolveArtDirectory(
        pluginID: String,
        gallery: PluginGalleryDefinition,
        installedRoot: URL
    ) -> URL {
        resolveArtDirectories(pluginID: pluginID, gallery: gallery, installedRoot: installedRoot).first
            ?? installedRoot.appendingPathComponent(gallery.artDirectory, isDirectory: true)
    }

    /// Preferred drop folder for personal art while developing from a checkout.
    static let easyAddArtDirectoryName = "Ascii_art"

    /// All art directories that contribute entries, highest priority first.
    /// Root `Ascii_art/` is the easy drop zone; plugin / App Support / bundle follow.
    static func resolveArtDirectories(
        pluginID: String,
        gallery: PluginGalleryDefinition,
        installedRoot: URL
    ) -> [URL] {
        var directories: [URL] = []
        var seen = Set<String>()

        func appendIfPresent(_ url: URL) {
            let path = url.standardizedFileURL.path
            guard !seen.contains(path), FileManager.default.fileExists(atPath: path) else {
                return
            }
            seen.insert(path)
            directories.append(url)
        }

        for root in developmentPackageRoots() {
            appendIfPresent(root.appendingPathComponent(easyAddArtDirectoryName, isDirectory: true))
        }

        if let developmentDirectory = developmentArtDirectory(pluginID: pluginID, artDirectory: gallery.artDirectory) {
            appendIfPresent(developmentDirectory)
        }

        appendIfPresent(installedRoot.appendingPathComponent(gallery.artDirectory, isDirectory: true))

        if let bundledDirectory = bundledArtDirectory(pluginID: pluginID, artDirectory: gallery.artDirectory) {
            appendIfPresent(bundledDirectory)
        }

        return directories
    }

    static func loadEntries(from directory: URL, fileManager: FileManager = .default) -> [AsciiArtEntry] {
        loadEntries(from: [directory], fileManager: fileManager)
    }

    /// Loads art from multiple folders. Earlier directories win when filenames collide.
    static func loadEntries(from directories: [URL], fileManager: FileManager = .default) -> [AsciiArtEntry] {
        var byName: [String: AsciiArtEntry] = [:]
        var order: [String] = []

        for directory in directories {
            guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
                continue
            }

            let candidates = files
                .filter { url in
                    let ext = url.pathExtension.lowercased()
                    return ext == "json" || ext.isEmpty
                }
                .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }

            for url in candidates {
                guard let data = try? Data(contentsOf: url) else { continue }
                let name = url.deletingPathExtension().lastPathComponent
                guard byName[name] == nil, let entry = AsciiArtEntry(data: data, name: name) else {
                    continue
                }
                byName[name] = entry
                order.append(name)
            }
        }

        return order.compactMap { byName[$0] }
    }

    private static func positiveModulo(_ value: Int, _ modulus: Int) -> Int {
        let remainder = value % modulus
        return remainder >= 0 ? remainder : remainder + modulus
    }

    private static func developmentArtDirectory(pluginID: String, artDirectory: String) -> URL? {
        for root in developmentPluginRoots() {
            let pluginDirectory = root.appendingPathComponent(pluginID, isDirectory: true)
                .appendingPathComponent(artDirectory, isDirectory: true)
            if FileManager.default.fileExists(atPath: pluginDirectory.path) {
                return pluginDirectory
            }
        }

        return nil
    }

    private static func developmentPackageRoots() -> [URL] {
        var roots: [URL] = []
        var seen = Set<String>()

        func append(_ url: URL) {
            let path = url.standardizedFileURL.path
            guard !seen.contains(path) else { return }
            seen.insert(path)
            roots.append(url)
        }

        append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true))

        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        append(packageRoot)

        return roots
    }

    private static func developmentPluginRoots() -> [URL] {
        developmentPackageRoots().map { $0.appendingPathComponent("Plugins", isDirectory: true) }
    }

    private static func bundledArtDirectory(pluginID: String, artDirectory: String) -> URL? {
        guard let resourceRoot = Bundle.module.resourceURL else {
            return nil
        }

        let candidates = [
            resourceRoot
                .appendingPathComponent("Plugins", isDirectory: true)
                .appendingPathComponent(pluginID, isDirectory: true)
                .appendingPathComponent(artDirectory, isDirectory: true),
            resourceRoot
                .appendingPathComponent("plugins", isDirectory: true)
                .appendingPathComponent(pluginID, isDirectory: true)
                .appendingPathComponent(artDirectory, isDirectory: true),
        ]

        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }
}

struct AsciiArtEntry: Hashable, Sendable, Identifiable {
    let id: String
    let content: String
    let frames: [String]
    let fps: Double
    let loopFrom: Int
    let columns: Int
    let rows: Int

    var isAnimated: Bool { frames.count > 1 }

    private static let placeholderPhrases: Set<String> = [
        "paste your ascii art here",
        "paste here",
    ]

    init?(data: Data, name: String? = nil) {
        let text = String(decoding: data, as: UTF8.self)

        if let payload = try? JSONDecoder().decode(AsciiArtPayload.self, from: data) {
            self.init(
                rawContent: payload.art,
                frames: payload.frames,
                fps: payload.fps,
                loopFrom: payload.loopFrom,
                name: name
            )
            return
        }

        if let extracted = Self.extractArtFromLooseJSONWrapper(text) {
            self.init(rawContent: extracted, name: name)
            return
        }

        self.init(rawContent: text, name: name)
    }

    init?(
        rawContent: String,
        frames: [String] = [],
        fps: Double = 12,
        loopFrom: Int = 0,
        name: String? = nil
    ) {
        let normalized = Self.normalizeRawContent(rawContent)
        let trimmed = normalized.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !trimmed.isEmpty, !Self.placeholderPhrases.contains(trimmed) else {
            return nil
        }

        let normalizedFrames = frames.map(Self.normalizeRawContent)

        let canonical = normalizedFrames.first ?? normalized
        let lines = canonical.split(separator: "\n", omittingEmptySubsequences: false)
        let columns = lines.map { $0.count }.max() ?? 0
        let rows = max(lines.count, 1)

        self.id = name ?? Self.identifier(for: normalized)
        self.content = normalized
        self.frames = normalizedFrames.isEmpty ? [normalized] : normalizedFrames
        self.fps = max(fps, 1)
        self.loopFrom = min(max(loopFrom, 0), max(self.frames.count - 1, 0))
        self.columns = columns
        self.rows = rows
    }

    func prefixed(pluginID: String) -> AsciiArtEntry {
        AsciiArtEntry(
            rawContent: content,
            frames: frames,
            fps: fps,
            loopFrom: loopFrom,
            name: "\(pluginID)/\(id)"
        ) ?? self
    }

    func frameContent(at date: Date, startedAt: Date) -> String {
        guard frames.count > 1 else {
            return content
        }

        let elapsed = max(date.timeIntervalSince(startedAt), 0)
        let frameIndex = Int(floor(elapsed * fps))
        if frameIndex < frames.count {
            return frames[frameIndex]
        }

        let loopFrames = Array(frames[loopFrom...])
        guard !loopFrames.isEmpty else {
            return frames.last ?? content
        }

        let loopIndex = (frameIndex - loopFrom) % loopFrames.count
        return loopFrames[loopIndex]
    }

    private static func identifier(for content: String) -> String {
        String(content.hashValue)
    }

    private static func normalizeRawContent(_ text: String) -> String {
        var normalized = text

        if normalized.first == "\u{FEFF}" {
            normalized.removeFirst()
        }

        normalized = normalized
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        return trimTrailingLineBreaks(from: normalized)
    }

    private static func trimTrailingLineBreaks(from text: String) -> String {
        var normalized = text

        while normalized.last == "\n" || normalized.last == "\r" {
            normalized.removeLast()
        }

        return normalized
    }

    private static func extractArtFromLooseJSONWrapper(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{"), trimmed.contains("\"art\"") else {
            return nil
        }

        guard let keyRange = trimmed.range(of: "\"art\"") else {
            return nil
        }

        var remainder = trimmed[keyRange.upperBound...]
        guard let colonIndex = remainder.firstIndex(of: ":") else {
            return nil
        }

        remainder = remainder[remainder.index(after: colonIndex)...]
        remainder = remainder.drop(while: \.isWhitespace)

        if remainder.first == "[" {
            return nil
        }

        if remainder.first == "\"" {
            remainder = remainder.dropFirst()
        }

        var content = String(remainder).trimmingCharacters(in: .whitespacesAndNewlines)

        if content.hasSuffix("\"}") {
            content = String(content.dropLast(2))
        } else if content.hasSuffix("}") {
            content = String(content.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            if content.hasSuffix("\"") {
                content = String(content.dropLast())
            }
        }

        return content
    }
}

private struct AsciiArtPayload: Decodable {
    let art: String
    let frames: [String]
    let fps: Double
    let loopFrom: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let decodedFrames = try Self.decodeFrameList(from: container, forKey: .frames)
        fps = try container.decodeIfPresent(Double.self, forKey: .fps) ?? 12
        loopFrom = try container.decodeIfPresent(Int.self, forKey: .loopFrom) ?? 0

        if let string = try? container.decode(String.self, forKey: .art) {
            art = string
            frames = decodedFrames
            return
        }

        if let lines = try? container.decode([String].self, forKey: .art) {
            art = lines.joined(separator: "\n")
            frames = decodedFrames
            return
        }

        if !decodedFrames.isEmpty {
            art = decodedFrames[0]
            frames = decodedFrames
            return
        }

        throw DecodingError.typeMismatch(
            String.self,
            DecodingError.Context(
                codingPath: container.codingPath + [CodingKeys.art],
                debugDescription: "Expected \"art\" to be a string or an array of strings, or provide \"frames\"."
            )
        )
    }

    private static func decodeFrameList(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> [String] {
        guard container.contains(key) else {
            return []
        }

        if let strings = try? container.decode([String].self, forKey: key) {
            return strings
        }

        if let nested = try? container.decode([[String]].self, forKey: key) {
            return nested.map { $0.joined(separator: "\n") }
        }

        return []
    }

    private enum CodingKeys: String, CodingKey {
        case art
        case frames
        case fps
        case loopFrom
    }
}
