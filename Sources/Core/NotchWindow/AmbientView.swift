import AppKit
import SwiftUI

// MARK: — Main ambient view (left pill + transparent notch center + right pill)

struct AmbientView: View {
    let controller: NotchController

    private static let pillWidth: CGFloat = NotchController.ambientPillWidth
    private static let pillGap: CGFloat = NotchController.ambientPillGap

    var body: some View {
        HStack(spacing: 0) {
            // Zone gauche — pochette / icône (padding gauche pour ne pas coller au bord)
            leftContent
                .frame(width: Self.pillWidth, height: controller.notchHeight)
                .padding(.leading, 8)

            // Centre — zone de l'encoche hardware (transparente visuellement)
            Spacer()

            // Zone droite — indicateur animé (padding droit pour ne pas coller au bord)
            rightContent
                .frame(width: Self.pillWidth, height: controller.notchHeight)
                .padding(.trailing, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: — Left pill content

    @ViewBuilder
    private var leftContent: some View {
        if let ambient = controller.ambientContent {
            switch ambient.kind {
            case .music(let artwork, _, _, _):
                if controller.ambientShowArtwork, let artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 26, height: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ambient.accentColor)
                }
            case .timer(let label, _):
                VStack(spacing: 1) {
                    Image(systemName: "timer")
                        .font(.system(size: 10, weight: .semibold))
                    Text(label)
                        .font(.system(size: 7, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(.white.opacity(0.75))
            case .dropzone(let count):
                VStack(spacing: 1) {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 10, weight: .semibold))
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    // MARK: — Right pill content

    @ViewBuilder
    private var rightContent: some View {
        if let ambient = controller.ambientContent {
            switch ambient.kind {
            case .music(_, let isPlaying, let elapsed, let duration):
                VStack(spacing: 2) {
                    MusicVisualizerView(color: ambient.accentColor, isPlaying: isPlaying)
                        .frame(width: 34, height: 14)
                    if controller.ambientShowProgress && duration > 0 {
                        TimelineView(.animation) { ctx in
                            let live = elapsed + (isPlaying ? ctx.date.timeIntervalSince(ambient.timestamp) : 0)
                            let progress = min(1.0, live / duration)
                            Capsule()
                                .fill(ambient.accentColor.opacity(0.5))
                                .frame(height: 2)
                                .overlay(
                                    GeometryReader { geo in
                                        Capsule()
                                            .fill(ambient.accentColor)
                                            .frame(width: geo.size.width * progress)
                                    },
                                    alignment: .leading
                                )
                        }
                        .frame(width: 34, height: 2)
                    }
                }
            case .timer(_, let progress):
                CircularProgressView(progress: progress, color: ambient.accentColor)
                    .frame(width: 22, height: 22)
            case .dropzone:
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ambient.accentColor)
            }
        }
    }
}

// MARK: — Animated waveform for music

struct MusicVisualizerView: View {
    let color: Color
    let isPlaying: Bool

    private let speeds: [Double] = [1.0, 1.4, 0.85, 1.2]
    private let phases: [Double] = [0, .pi / 3, .pi * 0.8, .pi * 1.5]

    var body: some View {
        TimelineView(.animation(paused: !isPlaying)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<4, id: \.self) { i in
                    let raw = sin(t * speeds[i] * .pi * 2 + phases[i])
                    let h = isPlaying ? 0.3 + 0.7 * (raw * 0.5 + 0.5) : 0.2
                    Capsule()
                        .fill(color)
                        .frame(width: 3, height: max(4, 18 * h))
                }
            }
        }
    }
}

// MARK: — Timer progress ring

struct CircularProgressView: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.18), lineWidth: 2)
            Circle()
                .trim(from: 0, to: max(0.02, 1 - progress))
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: — NSImage dominant color (CIAreaAverage)

public extension NSImage {
    var dominantColor: Color {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return .white }
        let inputImage = CIImage(cgImage: cgImage)
        guard
            let filter = CIFilter(name: "CIAreaAverage", parameters: [
                kCIInputImageKey: inputImage,
                kCIInputExtentKey: CIVector(cgRect: inputImage.extent),
            ]),
            let output = filter.outputImage
        else { return .white }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let ciCtx = CIContext(options: [.workingColorSpace: NSNull()])
        ciCtx.render(output, toBitmap: &bitmap, rowBytes: 4,
                     bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                     format: .RGBA8, colorSpace: nil)

        let r = Double(bitmap[0]) / 255
        let g = Double(bitmap[1]) / 255
        let b = Double(bitmap[2]) / 255
        // Fall back to white if the image is too dark to be legible as a tint
        let brightness = 0.299 * r + 0.587 * g + 0.114 * b
        return brightness < 0.18 ? .white : Color(red: r, green: g, blue: b)
    }
}
