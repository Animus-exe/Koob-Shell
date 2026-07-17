import AppKit
import SwiftUI

struct ShellThemeBackground: View {
  let theme: ThemeDefinition
  let border: ShellBorderStyle

  var body: some View {
    GeometryReader { geometry in
      let titleBarHeight = max(geometry.safeAreaInsets.top, 28)

      VStack(spacing: 0) {
        Color.clear
          .frame(height: titleBarHeight)
        shellFill(for: border)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .ignoresSafeArea()
  }

  @ViewBuilder
  private func shellFill(for style: ShellBorderStyle) -> some View {
    if style.usesCustomShellChrome {
      Rectangle()
        .fill(
          ShellStyleRendering.swiftUIFill(
            style: style,
            themeBackgroundHex: theme.backgroundColor
          )
        )
    } else {
      Color(nsColor: .windowBackgroundColor)
    }
  }
}
