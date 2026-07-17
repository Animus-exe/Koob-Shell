import Foundation
import Observation

@MainActor
@Observable
final class AppearanceStore {
    var config: AppearanceConfig = .fallback
    var rawJSON: String = ""
    var loadError: String?
    var onChange: (@MainActor () -> Void)?

    init() {
        reload()
    }

    func reload() {
        do {
            try ensureSupportFiles()
            let data = try Data(contentsOf: AppPaths.appearanceURL)
            var decoded = try AppearanceCodec.decode(from: data)
            let beforeNormalization = decoded
            decoded.normalizeGallerySettings()
            config = decoded
            if decoded != beforeNormalization {
                let normalizedData = try AppearanceCodec.encode(decoded)
                try FileManager.default.createDirectory(at: AppPaths.appSupportDirectory, withIntermediateDirectories: true, attributes: nil)
                try normalizedData.write(to: AppPaths.appearanceURL, options: .atomic)
                rawJSON = String(decoding: normalizedData, as: UTF8.self)
            } else {
                rawJSON = String(decoding: data, as: UTF8.self)
            }
            loadError = nil
            onChange?()
        } catch {
            config = .fallback
            rawJSON = (try? String(decoding: AppearanceCodec.encode(.fallback), as: UTF8.self)) ?? ""
            loadError = "Appearance config fallback loaded: \(error.localizedDescription)"
            onChange?()
        }
    }

    func saveRawJSON() throws {
        let data = Data(rawJSON.utf8)
        let decoded = try AppearanceCodec.decode(from: data)
        try FileManager.default.createDirectory(at: AppPaths.appSupportDirectory, withIntermediateDirectories: true, attributes: nil)
        try data.write(to: AppPaths.appearanceURL, options: .atomic)
        config = decoded
        reload()
    }

    func setActiveThemeID(_ id: String) throws {
        config.activeThemeID = id
        try saveConfig()
    }

    func setTerminalOpacity(_ value: Double) {
        applyUpdate {
            $0.terminalOpacity = value.clamped(to: 0.0 ... 1.0)
        }
    }

    func setGalleryEnabled(_ enabled: Bool) {
        applyUpdate {
            $0.setGalleryEnabled(enabled)
        }
    }

    func setGalleryOpacity(_ value: Double) {
        applyUpdate {
            $0.galleryOpacity = value.clamped(
                to: AppearanceConfig.minimumVisibleGalleryOpacity ... AppearanceConfig.maximumGalleryOpacity
            )
        }
    }

    func setGalleryTintColor(_ hex: String) {
        applyUpdate {
            $0.galleryTintColor = hex
        }
    }

    func setGalleryFullScreen(_ enabled: Bool) {
        applyUpdate {
            $0.galleryFullScreen = enabled
        }
    }

    func setGalleryIntervalSeconds(_ value: Double) {
        applyUpdate {
            $0.galleryIntervalSeconds = value.clamped(
                to: AppearanceConfig.minimumGalleryIntervalSeconds ... AppearanceConfig.maximumGalleryIntervalSeconds
            )
        }
    }

    func setGalleryRevolve(_ enabled: Bool) {
        applyUpdate {
            $0.galleryRevolve = enabled
        }
    }

    func setAllowPluginGalleries(_ enabled: Bool) {
        applyUpdate {
            $0.allowPluginGalleries = enabled
        }
    }

    func setColorOverride(_ key: AppearanceColorOverrideKey, hex: String?) {
        applyUpdate {
            switch key {
            case .foreground:
                $0.colorOverrides.foregroundColor = hex
            case .background:
                $0.colorOverrides.backgroundColor = hex
            case .accent:
                $0.colorOverrides.accentColor = hex
            }
        }
    }

    func setBorderPrimaryColor(_ hex: String?) {
        applyUpdate {
            $0.borderOverrides.primaryColor = hex
        }
    }

    func setBorderSecondaryColor(_ hex: String?) {
        applyUpdate {
            $0.borderOverrides.secondaryColor = hex
        }
    }

    func setBorderOpacity(_ value: Double) {
        applyUpdate {
            $0.borderOverrides.opacity = value.clamped(to: 0.0 ... 1.0)
        }
    }

    func setBorderColorDepth(_ value: Double) {
        applyUpdate {
            $0.borderOverrides.colorDepth = value.clamped(to: 0.0 ... 1.0)
        }
    }

    func clearBorderOverrides() {
        applyUpdate {
            $0.borderOverrides = .empty
        }
    }

    func setTitleBarPrimaryColor(_ hex: String?) {
        applyUpdate {
            $0.titleBarOverrides.primaryColor = hex
        }
    }

    func setTitleBarSecondaryColor(_ hex: String?) {
        applyUpdate {
            $0.titleBarOverrides.secondaryColor = hex
        }
    }

    func setTitleBarOpacity(_ value: Double) {
        applyUpdate {
            $0.titleBarOverrides.opacity = value.clamped(to: 0.0 ... 1.0)
        }
    }

    func setTitleBarColorDepth(_ value: Double) {
        applyUpdate {
            $0.titleBarOverrides.colorDepth = value.clamped(to: 0.0 ... 1.0)
        }
    }

    func clearTitleBarOverrides() {
        applyUpdate {
            $0.titleBarOverrides = .empty
        }
    }

    private func ensureSupportFiles() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: AppPaths.appSupportDirectory, withIntermediateDirectories: true, attributes: nil)

        if !fileManager.fileExists(atPath: AppPaths.appearanceURL.path) {
            let source = Bundle.module.url(forResource: "default-appearance", withExtension: "json")!
            try fileManager.copyItem(at: source, to: AppPaths.appearanceURL)
        }
    }

    private func saveConfig() throws {
        let data = try AppearanceCodec.encode(config)
        try FileManager.default.createDirectory(at: AppPaths.appSupportDirectory, withIntermediateDirectories: true, attributes: nil)
        try data.write(to: AppPaths.appearanceURL, options: .atomic)
        reload()
    }

    private func applyUpdate(_ update: (inout AppearanceConfig) -> Void) {
        do {
            update(&config)
            try saveConfig()
        } catch {
            loadError = "Appearance update error: \(error.localizedDescription)"
            reload()
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
