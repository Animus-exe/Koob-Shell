import AppKit
import SwiftUI

struct AsciiGalleryPluginView: View {
    let entries: [AsciiArtEntry]
    let appearance: AppearanceConfig

    var body: some View {
        if appearance.galleryEnabled, !entries.isEmpty {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let art = currentArt(at: timeline.date)
                AsciiArtBackdrop(
                    art: art,
                    frameContent: art.map { $0.frameContent(at: timeline.date, startedAt: artEpoch(for: $0, at: timeline.date)) } ?? "",
                    angle: appearance.galleryRevolve ? galleryAngle(at: timeline.date) : softSwayAngle(at: timeline.date),
                    driftOffset: galleryOffset(at: timeline.date),
                    breathScale: breathScale(at: timeline.date),
                    pulseOpacity: pulseOpacity(at: timeline.date),
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
        // Restart animated pieces each time they become current.
        return art.isAnimated ? slotStart : date
    }

    private func galleryAngle(at date: Date) -> Double {
        let cycle = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 72)
        return (cycle / 72) * 360
    }

    private func softSwayAngle(at date: Date) -> Double {
        sin(date.timeIntervalSinceReferenceDate / 7) * 3.5
    }

    private func galleryOffset(at date: Date) -> CGSize {
        let time = date.timeIntervalSinceReferenceDate
        return CGSize(
            width: sin(time / 8) * 22 + cos(time / 19) * 8,
            height: cos(time / 10) * 16 + sin(time / 15) * 6
        )
    }

    private func breathScale(at date: Date) -> CGFloat {
        1 + CGFloat(sin(date.timeIntervalSinceReferenceDate / 2.8) * 0.028)
    }

    private func pulseOpacity(at date: Date) -> Double {
        0.82 + 0.18 * (0.5 + 0.5 * sin(date.timeIntervalSinceReferenceDate / 2.2))
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
                .padding(18)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

private struct AsciiArtBackdrop: View {
    let art: AsciiArtEntry?
    let frameContent: String
    let angle: Double
    let driftOffset: CGSize
    let breathScale: CGFloat
    let pulseOpacity: Double
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

                ZStack {
                    // Soft ghost trail for depth.
                    artLayer(
                        content: frameContent,
                        layout: layout,
                        color: tintColor.opacity(opacity * 0.35 * pulseOpacity),
                        scale: breathScale * 1.035
                    )
                    .offset(x: -10, y: 8)
                    .blur(radius: 0.6)

                    artLayer(
                        content: frameContent,
                        layout: layout,
                        color: tintColor.opacity(opacity * pulseOpacity),
                        scale: breathScale
                    )

                    // Bright rim flash on the leading edge of the breath.
                    artLayer(
                        content: frameContent,
                        layout: layout,
                        color: tintColor.opacity(opacity * 0.22 * pulseOpacity),
                        scale: breathScale * 0.992
                    )
                    .blendMode(.plusLighter)
                    .offset(x: 4, y: -3)
                }
                .rotationEffect(.degrees(angle))
                .offset(driftOffset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(art.id)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.9), value: art?.id)
        .padding(isFullScreen ? 0 : 36)
        .clipped()
    }

    private func artLayer(
        content: String,
        layout: AsciiArtRenderLayout,
        color: Color,
        scale: CGFloat
    ) -> some View {
        Text(content)
            .font(artFont(size: layout.fontSize))
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .lineSpacing(layout.lineSpacing)
            .tracking(layout.tracking)
            .fixedSize(horizontal: true, vertical: true)
            .scaleEffect(layout.residualScale * scale, anchor: .center)
    }

    private func artFont(size: CGFloat) -> Font {
        if NSFont(name: "Menlo", size: size) != nil {
            return .custom("Menlo", size: size)
        }

        return .system(size: size, weight: .regular, design: .monospaced)
    }
}
