import AppKit
import SwiftUI

struct AsciiGalleryPluginView: View {
    let entries: [AsciiArtEntry]
    let appearance: AppearanceConfig

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        if appearance.galleryEnabled, !entries.isEmpty, appearance.galleryOpacity >= 0.01 {
            TimelineView(
                .animation(
                    minimumInterval: refreshInterval,
                    paused: scenePhase != .active
                )
            ) { timeline in
                let art = currentArt(at: timeline.date)
                let epoch = art.map { artEpoch(for: $0, at: timeline.date) }
                let frameContent = art.flatMap { entry in
                    epoch.map { entry.frameContent(at: timeline.date, startedAt: $0) }
                } ?? ""
                // Quantize rotation so SwiftUI isn't rebuilding text layout every tick.
                let angle = appearance.galleryRevolve
                    ? Double(Int(galleryAngle(at: timeline.date)))
                    : 0

                AsciiArtBackdrop(
                    art: art,
                    frameContent: frameContent,
                    angle: angle,
                    tintColor: Color(hex: appearance.galleryTintColor) ?? .white,
                    opacity: appearance.galleryOpacity,
                    isFullScreen: appearance.galleryFullScreen,
                    revolves: appearance.galleryRevolve
                )
            }
            .modifier(GalleryLayoutModifier(isFullScreen: appearance.galleryFullScreen))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
        }
    }

    /// Revolve stays smooth enough at 4fps; animated art tracks its own fps (capped at 10).
    private var refreshInterval: TimeInterval {
        if entries.contains(where: \.isAnimated) {
            let fps = entries.lazy.filter(\.isAnimated).map(\.fps).max() ?? 12
            return max(1.0 / min(fps, 10), 0.1)
        }
        if appearance.galleryRevolve {
            return 0.25
        }
        return max(appearance.galleryIntervalSeconds, 5)
    }

    private func currentArt(at date: Date) -> AsciiArtEntry? {
        guard !entries.isEmpty else { return nil }
        let index = AsciiArtGallery.rotatingIndex(
            at: date,
            count: entries.count,
            interval: appearance.galleryIntervalSeconds
        )
        return entries[index]
    }

    private func artEpoch(for art: AsciiArtEntry, at date: Date) -> Date {
        guard !entries.isEmpty else { return date }
        let interval = max(appearance.galleryIntervalSeconds, 1)
        let slot = Int(floor(date.timeIntervalSinceReferenceDate / interval))
        let slotStart = Date(timeIntervalSinceReferenceDate: Double(slot) * interval)
        return art.isAnimated ? slotStart : date
    }

    private func galleryAngle(at date: Date) -> Double {
        let cycle = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 72)
        return (cycle / 72) * 360
    }
}

private struct GalleryLayoutModifier: ViewModifier {
    let isFullScreen: Bool

    func body(content: Content) -> some View {
        if isFullScreen {
            content
                .ignoresSafeArea()
        } else {
            content
                .clipShape(Rectangle())
        }
    }
}

private struct AsciiArtBackdrop: View {
    let art: AsciiArtEntry?
    let frameContent: String
    let angle: Double
    let tintColor: Color
    let opacity: Double
    let isFullScreen: Bool
    let revolves: Bool

    var body: some View {
        GeometryReader { geometry in
            if let art {
                let layout = AsciiArtGalleryLayout.renderLayout(
                    viewport: geometry.size,
                    art: art,
                    isFullScreen: isFullScreen,
                    revolves: revolves
                )

                Text(frameContent)
                    .font(artFont(size: layout.fontSize))
                    .foregroundStyle(tintColor.opacity(opacity))
                    .multilineTextAlignment(.center)
                    .lineSpacing(layout.lineSpacing)
                    .tracking(layout.tracking)
                    .fixedSize(horizontal: true, vertical: true)
                    .scaleEffect(layout.residualScale, anchor: .center)
                    // Rasterize glyphs once; rotate the bitmap while revolving.
                    .drawingGroup(opaque: false)
                    .rotationEffect(.degrees(angle))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(art.id)
            }
        }
        .clipped()
    }

    private func artFont(size: CGFloat) -> Font {
        if NSFont(name: "Menlo", size: size) != nil {
            return .custom("Menlo", size: size)
        }

        return .system(size: size, weight: .regular, design: .monospaced)
    }
}
