import AppKit
import SwiftUI

struct ShellWindowReader: NSViewRepresentable {
  let theme: ThemeDefinition
  let border: ShellBorderStyle
  let titleBar: ShellBorderStyle

  func makeNSView(context: Context) -> NSView {
    let view = NSView(frame: .zero)
    view.isHidden = true
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    applyChrome(from: nsView)
  }

  private func applyChrome(from view: NSView, attempt: Int = 0) {
    guard attempt < 20 else { return }

    guard let window = view.window else {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        applyChrome(from: view, attempt: attempt + 1)
      }
      return
    }

    ShellWindowChromeApplier.apply(
      window: window,
      theme: theme,
      border: border,
      titleBar: titleBar
    )

    if window.identifier?.rawValue != AppPaths.preferencesWindowIdentifier {
      window.identifier = NSUserInterfaceItemIdentifier(AppPaths.mainWindowIdentifier)
    }
  }
}

@MainActor
enum ShellWindowChromeApplier {
  private struct AppliedChrome: Equatable {
    let themeID: String
    let themeBackground: String
    let border: ShellBorderStyle
    let titleBar: ShellBorderStyle
  }

  private static var overlays: [ObjectIdentifier: TitleBarChromeOverlayView] = [:]
  private static var lastApplied: [ObjectIdentifier: AppliedChrome] = [:]

  static func apply(
    window: NSWindow,
    theme: ThemeDefinition,
    border: ShellBorderStyle,
    titleBar: ShellBorderStyle
  ) {
    let key = ObjectIdentifier(window)
    let signature = AppliedChrome(
      themeID: theme.id,
      themeBackground: theme.backgroundColor,
      border: border,
      titleBar: titleBar
    )
    if lastApplied[key] == signature {
      return
    }

    WindowChromeConfigurator.apply(to: window, titleBar: titleBar, border: border)

    guard titleBar.usesCustomShellChrome else {
      if let existing = overlays[key] {
        if let token = existing.windowResizeObserver {
          NotificationCenter.default.removeObserver(token)
        }
        existing.removeFromSuperview()
      }
      overlays.removeValue(forKey: key)
      lastApplied[key] = signature
      return
    }

    guard let frameView = window.contentView?.superview else { return }

    let overlay: TitleBarChromeOverlayView
    if let existing = overlays[key], existing.superview === frameView {
      overlay = existing
    } else {
      overlay = TitleBarChromeOverlayView()
      overlay.translatesAutoresizingMaskIntoConstraints = false
      frameView.addSubview(overlay, positioned: .below, relativeTo: nil)
      overlays[key] = overlay

      NSLayoutConstraint.activate([
        overlay.leadingAnchor.constraint(equalTo: frameView.leadingAnchor),
        overlay.trailingAnchor.constraint(equalTo: frameView.trailingAnchor),
        overlay.topAnchor.constraint(equalTo: frameView.topAnchor),
      ])
      overlay.heightConstraint = overlay.heightAnchor.constraint(equalToConstant: window.titleBarThickness)
      overlay.heightConstraint?.isActive = true
    }

    overlay.heightConstraint?.constant = window.titleBarThickness
    overlay.apply(style: titleBar, themeBackgroundHex: theme.backgroundColor)

    if overlay.windowResizeObserver == nil {
      let token = NotificationCenter.default.addObserver(
        forName: NSWindow.didResizeNotification,
        object: window,
        queue: .main
      ) { [weak overlay, weak window] _ in
        Task { @MainActor in
          guard let window else { return }
          overlay?.heightConstraint?.constant = window.titleBarThickness
        }
      }
      overlay.windowResizeObserver = token
    }

    lastApplied[key] = signature
  }
}

@MainActor
final class TitleBarChromeOverlayView: NSView {
  private let fillLayer = CAGradientLayer()
  private var lastStyle: ShellBorderStyle?
  private var lastThemeBackgroundHex: String?
  var heightConstraint: NSLayoutConstraint?
  var windowResizeObserver: NSObjectProtocol?

  override var isOpaque: Bool { false }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
    fillLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
    layer?.addSublayer(fillLayer)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func apply(style: ShellBorderStyle, themeBackgroundHex: String) {
    if lastStyle == style, lastThemeBackgroundHex == themeBackgroundHex {
      return
    }
    lastStyle = style
    lastThemeBackgroundHex = themeBackgroundHex
    isHidden = !style.usesCustomShellChrome
    ShellStyleLayer.apply(style: style, themeBackgroundHex: themeBackgroundHex, to: fillLayer)
    fillLayer.frame = bounds
    needsDisplay = true
  }

  override func layout() {
    super.layout()
    fillLayer.frame = bounds
  }
}

enum WindowChromeConfigurator {
  @MainActor
  static func apply(
    to window: NSWindow?,
    titleBar: ShellBorderStyle?,
    border: ShellBorderStyle?,
    forceCustom: Bool? = nil
  ) {
    guard let window else { return }

    let usesCustomChrome = forceCustom ?? [
      titleBar?.usesCustomShellChrome,
      border?.usesCustomShellChrome,
    ].contains(true)

    if usesCustomChrome {
      if !window.styleMask.contains(.fullSizeContentView)
        || !window.titlebarAppearsTransparent
        || window.isOpaque
      {
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.toolbarStyle = .unified
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
      }
    } else if window.styleMask.contains(.fullSizeContentView)
      || window.titlebarAppearsTransparent
      || !window.isOpaque
    {
      window.styleMask.remove(.fullSizeContentView)
      window.titlebarAppearsTransparent = false
      window.titlebarSeparatorStyle = .automatic
      window.isOpaque = true
      window.backgroundColor = .windowBackgroundColor
      window.isMovableByWindowBackground = false
    }
  }
}

extension NSWindow {
  @MainActor
  var titleBarThickness: CGFloat {
    let topInset = frame.height - contentLayoutRect.maxY
    if topInset > 1 {
      return topInset
    }

    return max(frame.height - contentLayoutRect.height - contentLayoutRect.origin.y, 28)
  }
}
