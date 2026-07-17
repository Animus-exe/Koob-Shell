import AppKit
import SwiftUI

enum ShellStyleRendering {
  static func swiftUIFill(style: ShellBorderStyle, themeBackgroundHex: String) -> AnyShapeStyle {
    if style.usesGradientBorder,
       let primary = style.primaryColor,
       let secondary = style.secondaryColor {
      let endHex = ShellBorderStyle.blendedHexColor(
        primary: primary,
        secondary: secondary,
        depth: style.colorDepth
      )
      return AnyShapeStyle(
        LinearGradient(
          colors: [
            shellColor(primary).opacity(style.opacity),
            shellColor(endHex).opacity(style.opacity),
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
    }

    if let primary = style.primaryColor {
      return AnyShapeStyle(shellColor(primary).opacity(style.opacity))
    }

    return AnyShapeStyle(Color(nsColor: .windowBackgroundColor))
  }

  static func shellColor(_ hex: String) -> Color {
    Color(hex: hex) ?? Color(nsColor: .windowBackgroundColor)
  }
}

enum ShellStyleLayer {
  static func apply(style: ShellBorderStyle, themeBackgroundHex: String, to layer: CAGradientLayer) {
    let opacity = CGFloat(style.opacity.clamped(to: 0 ... 1))

    if style.usesGradientBorder,
       let primaryHex = style.primaryColor,
       let secondaryHex = style.secondaryColor,
       let primary = NSColor(hex: primaryHex),
       let secondary = NSColor(hex: secondaryHex) {
      let endColor = blend(
        primary,
        secondary,
        factor: style.colorDepth.clamped(to: 0 ... 1)
      )
      layer.colors = [
        primary.withAlphaComponent(opacity).cgColor,
        endColor.withAlphaComponent(opacity).cgColor,
      ]
      layer.startPoint = CGPoint(x: 0, y: 1)
      layer.endPoint = CGPoint(x: 1, y: 0)
      layer.backgroundColor = nil
      return
    }

    if let primaryHex = style.primaryColor, let primary = NSColor(hex: primaryHex) {
      let base = NSColor(hex: themeBackgroundHex) ?? .windowBackgroundColor
      let fill = blend(primary, base, factor: Double(opacity))
      layer.colors = nil
      layer.backgroundColor = fill.cgColor
      return
    }

    layer.colors = nil
    layer.backgroundColor = NSColor.windowBackgroundColor.cgColor
  }

  private static func blend(_ primary: NSColor, _ secondary: NSColor, factor: Double) -> NSColor {
    let blend = CGFloat(factor.clamped(to: 0 ... 1))
    let primaryRGB = primary.usingColorSpace(.deviceRGB) ?? primary
    let secondaryRGB = secondary.usingColorSpace(.deviceRGB) ?? secondary

    return NSColor(
      red: primaryRGB.redComponent + (secondaryRGB.redComponent - primaryRGB.redComponent) * blend,
      green: primaryRGB.greenComponent + (secondaryRGB.greenComponent - primaryRGB.greenComponent) * blend,
      blue: primaryRGB.blueComponent + (secondaryRGB.blueComponent - primaryRGB.blueComponent) * blend,
      alpha: 1
    )
  }
}

extension Color {
  init?(hex: String) {
    let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else { return nil }
    self.init(
      red: Double((value >> 16) & 0xFF) / 255.0,
      green: Double((value >> 8) & 0xFF) / 255.0,
      blue: Double(value & 0xFF) / 255.0
    )
  }
}

extension NSColor {
  convenience init?(hex: String) {
    let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else { return nil }
    self.init(
      red: CGFloat((value >> 16) & 0xFF) / 255.0,
      green: CGFloat((value >> 8) & 0xFF) / 255.0,
      blue: CGFloat(value & 0xFF) / 255.0,
      alpha: 1
    )
  }

  var hexString: String {
    let rgbColor = usingColorSpace(.deviceRGB) ?? .white
    let red = Int(round(rgbColor.redComponent * 255))
    let green = Int(round(rgbColor.greenComponent * 255))
    let blue = Int(round(rgbColor.blueComponent * 255))
    return String(format: "#%02X%02X%02X", red, green, blue)
  }
}

private extension Double {
  func clamped(to range: ClosedRange<Double>) -> Double {
    min(max(self, range.lowerBound), range.upperBound)
  }
}
