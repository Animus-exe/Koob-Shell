import AppKit
import CoreGraphics

struct AsciiArtRenderLayout: Equatable, Sendable {
    let fontSize: CGFloat
    let lineSpacing: CGFloat
    let tracking: CGFloat
    let residualScale: CGFloat
}

enum AsciiArtGalleryLayout {
    static let referenceFontSize: CGFloat = 12
    private static let minimumFontSize: CGFloat = 1
    private static let maximumFontSize: CGFloat = 4096
    private static let rotationCoverMultiplier = CGFloat(2).squareRoot()
    private static let refinementIterations = 14

    static func renderLayout(
        viewport: CGSize,
        art: AsciiArtEntry,
        isFullScreen: Bool,
        revolves: Bool
    ) -> AsciiArtRenderLayout {
        guard viewport.width > 0, viewport.height > 0 else {
            return layout(for: referenceFontSize)
        }

        let target = dynamicTarget(
            viewport: viewport,
            art: art,
            isFullScreen: isFullScreen,
            revolves: revolves
        )
        let fontSize = fitFontSize(viewport: target, content: art.content)
        let measuredSize = measureArtSize(content: art.content, fontSize: fontSize)
        let residualScale = residualScaleToFit(measuredSize: measuredSize, target: target)

        return AsciiArtRenderLayout(
            fontSize: fontSize,
            lineSpacing: lineSpacing(for: fontSize),
            tracking: tracking(for: fontSize),
            residualScale: residualScale
        )
    }

    static func dynamicFillRatio(for art: AsciiArtEntry, isFullScreen: Bool) -> CGFloat {
        let characterCount = CGFloat(max(art.columns * art.rows, 1))
        let normalizedSize = min(max((log10(characterCount) - 2) / 2, 0), 1)

        if isFullScreen {
            return 1
        }

        let maxFill: CGFloat = 0.82
        let minFill: CGFloat = 0.62
        return maxFill - (normalizedSize * (maxFill - minFill))
    }

    static func measureArtSize(content: String, fontSize: CGFloat) -> CGSize {
        let font = artFont(size: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let spacing = lineSpacing(for: fontSize)
        let lineHeight = (font.ascender - font.descender) + spacing
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var maxWidth: CGFloat = 0
        for line in lines {
            let width = (line as NSString).size(withAttributes: attributes).width
            maxWidth = max(maxWidth, width)
        }

        let totalHeight = lineHeight * CGFloat(max(lines.count, 1))
        return CGSize(width: max(maxWidth, 1), height: max(totalHeight, 1))
    }

    static func lineSpacing(for fontSize: CGFloat) -> CGFloat {
        max(-fontSize * 0.12, -1.5)
    }

    static func tracking(for fontSize: CGFloat) -> CGFloat {
        max(-fontSize * 0.012, -0.12)
    }

    private static func layout(for fontSize: CGFloat) -> AsciiArtRenderLayout {
        AsciiArtRenderLayout(
            fontSize: fontSize,
            lineSpacing: lineSpacing(for: fontSize),
            tracking: tracking(for: fontSize),
            residualScale: 1
        )
    }

    private static func dynamicTarget(
        viewport: CGSize,
        art: AsciiArtEntry,
        isFullScreen: Bool,
        revolves: Bool
    ) -> CGSize {
        let fillRatio = dynamicFillRatio(for: art, isFullScreen: isFullScreen)
        var target = CGSize(
            width: max(viewport.width * fillRatio, 1),
            height: max(viewport.height * fillRatio, 1)
        )

        if revolves {
            target.width /= rotationCoverMultiplier
            target.height /= rotationCoverMultiplier
        }

        return target
    }

    private static func residualScaleToFit(measuredSize: CGSize, target: CGSize) -> CGFloat {
        guard measuredSize.width > 0, measuredSize.height > 0, target.width > 0, target.height > 0 else {
            return 1
        }

        let widthScale = target.width / measuredSize.width
        let heightScale = target.height / measuredSize.height
        let needed = min(widthScale, heightScale)
        return needed < 0.999 ? needed : 1
    }

    private static func fitFontSize(viewport: CGSize, content: String) -> CGFloat {
        let initialGuess = fontSizeGuess(
            viewport: viewport,
            content: content,
            comparison: { widthScale, heightScale in
                min(widthScale, heightScale)
            }
        )

        return refinedFontSize(
            viewport: viewport,
            content: content,
            initialGuess: initialGuess,
            satisfies: { size in
                size.width <= viewport.width && size.height <= viewport.height
            },
            increaseWhenMissing: false
        )
    }

    private static func fontSizeGuess(
        viewport: CGSize,
        content: String,
        comparison: (CGFloat, CGFloat) -> CGFloat
    ) -> CGFloat {
        let referenceSize = measureArtSize(content: content, fontSize: referenceFontSize)
        guard referenceSize.width > 0, referenceSize.height > 0 else {
            return referenceFontSize
        }

        let widthScale = viewport.width / referenceSize.width
        let heightScale = viewport.height / referenceSize.height
        let scale = comparison(widthScale, heightScale)
        return clamp(referenceFontSize * scale)
    }

    private static func refinedFontSize(
        viewport: CGSize,
        content: String,
        initialGuess: CGFloat,
        satisfies: (CGSize) -> Bool,
        increaseWhenMissing: Bool
    ) -> CGFloat {
        var low = minimumFontSize
        var high = max(initialGuess, minimumFontSize)
        var best = initialGuess

        while !satisfies(measureArtSize(content: content, fontSize: high)) && high < maximumFontSize {
            high = min(high * 2, maximumFontSize)
        }

        if increaseWhenMissing {
            for _ in 0..<refinementIterations {
                let mid = (low + high) / 2
                let size = measureArtSize(content: content, fontSize: mid)

                if satisfies(size) {
                    best = mid
                    high = mid
                } else {
                    low = mid
                }
            }
        } else {
            for _ in 0..<refinementIterations {
                let mid = (low + high) / 2
                let size = measureArtSize(content: content, fontSize: mid)

                if satisfies(size) {
                    best = mid
                    low = mid
                } else {
                    high = mid
                }
            }
        }

        return clamp(best)
    }

    private static func clamp(_ fontSize: CGFloat) -> CGFloat {
        min(max(fontSize, minimumFontSize), maximumFontSize)
    }

    private static func artFont(size: CGFloat) -> NSFont {
        NSFont(name: "Menlo", size: size) ?? .monospacedSystemFont(ofSize: size, weight: .regular)
    }
}
