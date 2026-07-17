import AppKit
import SwiftUI

struct PreferencesView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Base theme", selection: activeThemeBinding) {
                    ForEach(viewModel.availableThemes) { item in
                        Text("\(item.theme.name) (\(item.sourceName))")
                            .tag(item.theme.id)
                    }
                }
            }

            Section("Shell Theme") {
                ColorPicker(
                    "Primary color",
                    selection: borderPrimaryBinding,
                    supportsOpacity: false
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Shell opacity")
                    Slider(value: borderOpacityBinding, in: 0.0 ... 1.0)
                    Text("\(Int(resolvedBorder.opacity * 100))% opacity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle("Two-color gradient", isOn: borderGradientEnabledBinding)

                if borderGradientEnabled {
                    ColorPicker(
                        "Second color",
                        selection: borderSecondaryBinding,
                        supportsOpacity: false
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color depth")
                        Slider(value: borderColorDepthBinding, in: 0.0 ... 1.0)
                        Text("\(Int(resolvedBorder.colorDepth * 100))% blend")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Title Bar") {
                Toggle("Match shell theme", isOn: titleBarMatchesShellBinding)

                if !titleBarMatchesShell {
                    ColorPicker(
                        "Primary color",
                        selection: titleBarPrimaryBinding,
                        supportsOpacity: false
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title bar opacity")
                        Slider(value: titleBarOpacityBinding, in: 0.0 ... 1.0)
                        Text("\(Int(resolvedTitleBar.opacity * 100))% opacity")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Toggle("Two-color gradient", isOn: titleBarGradientEnabledBinding)

                    if titleBarGradientEnabled {
                        ColorPicker(
                            "Second color",
                            selection: titleBarSecondaryBinding,
                            supportsOpacity: false
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Color depth")
                            Slider(value: titleBarColorDepthBinding, in: 0.0 ... 1.0)
                            Text("\(Int(resolvedTitleBar.colorDepth * 100))% blend")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Terminal") {
                ColorPicker("Foreground", selection: colorBinding(for: .foreground, fallback: viewModel.activeTheme.foregroundColor), supportsOpacity: false)
                ColorPicker("Background", selection: colorBinding(for: .background, fallback: viewModel.activeTheme.backgroundColor), supportsOpacity: false)
                ColorPicker("Accent / Cursor", selection: colorBinding(for: .accent, fallback: viewModel.activeTheme.accentColor), supportsOpacity: false)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Terminal transparency")
                    Slider(value: terminalOpacityBinding, in: 0.0 ... 1.0)
                    Text("\(Int(viewModel.appearanceStore.config.terminalOpacity * 100))% opacity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("ASCII Gallery") {
                Toggle("Enable gallery", isOn: galleryEnabledBinding)

                Toggle("Allow plugin galleries", isOn: allowPluginGalleriesBinding)

                if viewModel.availableGalleries.isEmpty {
                    Text("No gallery plugins loaded. Add a plugin with a gallery section to \(AppPaths.pluginsDirectory.path).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Loaded from: \(viewModel.availableGalleries.map(\.pluginName).joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("The gallery sits behind the terminal. Lower terminal opacity to reveal it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Gallery strength")
                    Slider(
                        value: galleryOpacityBinding,
                        in: AppearanceConfig.minimumVisibleGalleryOpacity ... AppearanceConfig.maximumGalleryOpacity
                    )
                    .disabled(!viewModel.appearanceStore.config.galleryEnabled)
                    Text(String(format: "%.0f%% visible", viewModel.appearanceStore.config.galleryOpacity * 100))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ColorPicker("Gallery tint", selection: galleryTintBinding, supportsOpacity: false)
                    .disabled(!viewModel.appearanceStore.config.galleryEnabled)

                Toggle("Full screen", isOn: galleryFullScreenBinding)
                    .disabled(!viewModel.appearanceStore.config.galleryEnabled)

                Toggle("Revolve", isOn: galleryRevolveBinding)
                    .disabled(!viewModel.appearanceStore.config.galleryEnabled)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Time between images")
                    Slider(
                        value: galleryIntervalBinding,
                        in: AppearanceConfig.minimumGalleryIntervalSeconds ... AppearanceConfig.maximumGalleryIntervalSeconds,
                        step: 1
                    )
                    .disabled(!viewModel.appearanceStore.config.galleryEnabled)
                    Text("\(Int(viewModel.appearanceStore.config.galleryIntervalSeconds)) seconds")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Use Theme Defaults") {
                    viewModel.appearanceStore.setColorOverride(.foreground, hex: nil)
                    viewModel.appearanceStore.setColorOverride(.background, hex: nil)
                    viewModel.appearanceStore.setColorOverride(.accent, hex: nil)
                    viewModel.appearanceStore.clearBorderOverrides()
                    viewModel.appearanceStore.clearTitleBarOverrides()
                }
            }

            if viewModel.workflowRuntime.isActive {
                Section("Workflow Intelligence") {
                    Toggle("Show session inspector", isOn: workflowInspectorBinding)

                    Toggle("Capture commands", isOn: workflowCaptureBinding)

                    Picker("Destructive warnings", selection: workflowWarningsBinding) {
                        ForEach(DestructiveWarningMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue.capitalized).tag(mode)
                        }
                    }

                    Toggle("Auto-summary on shell exit", isOn: workflowAutoSummaryBinding)

                    if let plugin = viewModel.workflowRuntime.activePlugin {
                        Text("Plugin: \(plugin.manifest.name) v\(plugin.manifest.version)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let error = viewModel.workflowRuntime.activationError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 460)
    }

    private var resolvedTitleBar: ShellBorderStyle {
        viewModel.activeTitleBar
    }

    private var baseThemeTitleBar: ShellBorderStyle {
        let theme = viewModel.availableThemes
            .first(where: { $0.theme.id == viewModel.appearanceStore.config.activeThemeID })?
            .theme
        return theme?.titleBar ?? theme?.resolvedBorder() ?? .defaultBorder
    }

    private var titleBarMatchesShell: Bool {
        viewModel.appearanceStore.config.titleBarOverrides == .empty
    }

    private var titleBarGradientEnabled: Bool {
        resolvedTitleBar.usesGradientBorder
    }

    private var titleBarMatchesShellBinding: Binding<Bool> {
        Binding(
            get: { titleBarMatchesShell },
            set: { matches in
                if matches {
                    viewModel.appearanceStore.clearTitleBarOverrides()
                } else {
                    let shell = viewModel.activeBorder
                    viewModel.appearanceStore.setTitleBarPrimaryColor(shell.primaryColor ?? "#8E8E93")
                    if let secondary = shell.secondaryColor {
                        viewModel.appearanceStore.setTitleBarSecondaryColor(secondary)
                    }
                    viewModel.appearanceStore.setTitleBarOpacity(shell.opacity)
                    viewModel.appearanceStore.setTitleBarColorDepth(shell.colorDepth)
                }
            }
        )
    }

    private var titleBarPrimaryBinding: Binding<Color> {
        Binding(
            get: {
                let hex = viewModel.appearanceStore.config.titleBarOverrides.primaryColor
                    ?? baseThemeTitleBar.primaryColor
                    ?? "#8E8E93"
                return Color(hex: hex) ?? .gray
            },
            set: { newValue in
                viewModel.appearanceStore.setTitleBarPrimaryColor(NSColor(newValue).hexString)
            }
        )
    }

    private var titleBarSecondaryBinding: Binding<Color> {
        Binding(
            get: {
                let hex = viewModel.appearanceStore.config.titleBarOverrides.secondaryColor
                    ?? baseThemeTitleBar.secondaryColor
                    ?? "#A855F7"
                return Color(hex: hex) ?? .purple
            },
            set: { newValue in
                viewModel.appearanceStore.setTitleBarSecondaryColor(NSColor(newValue).hexString)
            }
        )
    }

    private var titleBarOpacityBinding: Binding<Double> {
        Binding(
            get: {
                viewModel.appearanceStore.config.titleBarOverrides.opacity ?? baseThemeTitleBar.opacity
            },
            set: { viewModel.appearanceStore.setTitleBarOpacity($0) }
        )
    }

    private var titleBarColorDepthBinding: Binding<Double> {
        Binding(
            get: {
                viewModel.appearanceStore.config.titleBarOverrides.colorDepth ?? baseThemeTitleBar.colorDepth
            },
            set: { viewModel.appearanceStore.setTitleBarColorDepth($0) }
        )
    }

    private var titleBarGradientEnabledBinding: Binding<Bool> {
        Binding(
            get: { titleBarGradientEnabled },
            set: { enabled in
                if enabled {
                    if viewModel.appearanceStore.config.titleBarOverrides.secondaryColor == nil,
                       baseThemeTitleBar.secondaryColor == nil {
                        viewModel.appearanceStore.setTitleBarSecondaryColor("#A855F7")
                    }
                    if viewModel.appearanceStore.config.titleBarOverrides.colorDepth == nil,
                       baseThemeTitleBar.colorDepth <= 0.01 {
                        viewModel.appearanceStore.setTitleBarColorDepth(0.5)
                    }
                } else {
                    viewModel.appearanceStore.setTitleBarSecondaryColor("")
                    viewModel.appearanceStore.setTitleBarColorDepth(0)
                }
            }
        )
    }

    private var resolvedBorder: ShellBorderStyle {
        viewModel.activeBorder
    }

    private var baseThemeBorder: ShellBorderStyle {
        viewModel.availableThemes
            .first(where: { $0.theme.id == viewModel.appearanceStore.config.activeThemeID })?
            .theme
            .resolvedBorder() ?? .defaultBorder
    }

    private var borderGradientEnabled: Bool {
        resolvedBorder.usesGradientBorder
    }

    private var borderPrimaryBinding: Binding<Color> {
        Binding(
            get: {
                let hex = viewModel.appearanceStore.config.borderOverrides.primaryColor
                    ?? baseThemeBorder.primaryColor
                    ?? "#8E8E93"
                return Color(hex: hex) ?? .gray
            },
            set: { newValue in
                viewModel.appearanceStore.setBorderPrimaryColor(NSColor(newValue).hexString)
            }
        )
    }

    private var borderSecondaryBinding: Binding<Color> {
        Binding(
            get: {
                let hex = viewModel.appearanceStore.config.borderOverrides.secondaryColor
                    ?? baseThemeBorder.secondaryColor
                    ?? "#A855F7"
                return Color(hex: hex) ?? .purple
            },
            set: { newValue in
                viewModel.appearanceStore.setBorderSecondaryColor(NSColor(newValue).hexString)
            }
        )
    }

    private var borderOpacityBinding: Binding<Double> {
        Binding(
            get: {
                viewModel.appearanceStore.config.borderOverrides.opacity ?? baseThemeBorder.opacity
            },
            set: { viewModel.appearanceStore.setBorderOpacity($0) }
        )
    }

    private var borderColorDepthBinding: Binding<Double> {
        Binding(
            get: {
                viewModel.appearanceStore.config.borderOverrides.colorDepth ?? baseThemeBorder.colorDepth
            },
            set: { viewModel.appearanceStore.setBorderColorDepth($0) }
        )
    }

    private var borderGradientEnabledBinding: Binding<Bool> {
        Binding(
            get: { borderGradientEnabled },
            set: { enabled in
                if enabled {
                    if viewModel.appearanceStore.config.borderOverrides.secondaryColor == nil,
                       baseThemeBorder.secondaryColor == nil {
                        viewModel.appearanceStore.setBorderSecondaryColor("#A855F7")
                    }
                    if viewModel.appearanceStore.config.borderOverrides.colorDepth == nil,
                       baseThemeBorder.colorDepth <= 0.01 {
                        viewModel.appearanceStore.setBorderColorDepth(0.5)
                    }
                } else {
                    viewModel.appearanceStore.setBorderSecondaryColor("")
                    viewModel.appearanceStore.setBorderColorDepth(0)
                }
            }
        )
    }

    private var activeThemeBinding: Binding<String> {
        Binding(
            get: { viewModel.appearanceStore.config.activeThemeID },
            set: { newValue in
                try? viewModel.appearanceStore.setActiveThemeID(newValue)
            }
        )
    }

    private var terminalOpacityBinding: Binding<Double> {
        Binding(
            get: { viewModel.appearanceStore.config.terminalOpacity },
            set: { viewModel.appearanceStore.setTerminalOpacity($0) }
        )
    }

    private var galleryEnabledBinding: Binding<Bool> {
        Binding(
            get: { viewModel.appearanceStore.config.galleryEnabled },
            set: { viewModel.appearanceStore.setGalleryEnabled($0) }
        )
    }

    private var allowPluginGalleriesBinding: Binding<Bool> {
        Binding(
            get: { viewModel.appearanceStore.config.allowPluginGalleries },
            set: { viewModel.appearanceStore.setAllowPluginGalleries($0) }
        )
    }

    private var galleryOpacityBinding: Binding<Double> {
        Binding(
            get: { viewModel.appearanceStore.config.galleryOpacity },
            set: { viewModel.appearanceStore.setGalleryOpacity($0) }
        )
    }

    private var galleryTintBinding: Binding<Color> {
        Binding(
            get: {
                Color(hex: viewModel.appearanceStore.config.galleryTintColor) ?? .white
            },
            set: { newValue in
                viewModel.appearanceStore.setGalleryTintColor(NSColor(newValue).hexString)
            }
        )
    }

    private var galleryFullScreenBinding: Binding<Bool> {
        Binding(
            get: { viewModel.appearanceStore.config.galleryFullScreen },
            set: { viewModel.appearanceStore.setGalleryFullScreen($0) }
        )
    }

    private var galleryRevolveBinding: Binding<Bool> {
        Binding(
            get: { viewModel.appearanceStore.config.galleryRevolve },
            set: { viewModel.appearanceStore.setGalleryRevolve($0) }
        )
    }

    private var galleryIntervalBinding: Binding<Double> {
        Binding(
            get: { viewModel.appearanceStore.config.galleryIntervalSeconds },
            set: { viewModel.appearanceStore.setGalleryIntervalSeconds($0) }
        )
    }

    private func colorBinding(for key: AppearanceColorOverrideKey, fallback: String) -> Binding<Color> {
        Binding(
            get: {
                let overrideColor: String?
                switch key {
                case .foreground:
                    overrideColor = viewModel.appearanceStore.config.colorOverrides.foregroundColor
                case .background:
                    overrideColor = viewModel.appearanceStore.config.colorOverrides.backgroundColor
                case .accent:
                    overrideColor = viewModel.appearanceStore.config.colorOverrides.accentColor
                }

                return Color(hex: overrideColor ?? fallback) ?? .white
            },
            set: { newValue in
                viewModel.appearanceStore.setColorOverride(key, hex: NSColor(newValue).hexString)
            }
        )
    }

    private var workflowInspectorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.showWorkflowInspector },
            set: { viewModel.showWorkflowInspector = $0 }
        )
    }

    private var workflowCaptureBinding: Binding<Bool> {
        Binding(
            get: { viewModel.workflowRuntime.settings.captureEnabled },
            set: { enabled in
                var settings = viewModel.workflowRuntime.settings
                settings.captureEnabled = enabled
                viewModel.updateWorkflowSettings(settings)
            }
        )
    }

    private var workflowWarningsBinding: Binding<DestructiveWarningMode> {
        Binding(
            get: { viewModel.workflowRuntime.settings.destructiveWarnings },
            set: { mode in
                var settings = viewModel.workflowRuntime.settings
                settings.destructiveWarnings = mode
                viewModel.updateWorkflowSettings(settings)
            }
        )
    }

    private var workflowAutoSummaryBinding: Binding<Bool> {
        Binding(
            get: { viewModel.workflowRuntime.settings.autoSummaryOnExit },
            set: { enabled in
                var settings = viewModel.workflowRuntime.settings
                settings.autoSummaryOnExit = enabled
                viewModel.updateWorkflowSettings(settings)
            }
        )
    }
}
