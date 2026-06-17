import Core
import SwiftUI

struct MediaContentView: View {
    var module: MediaModule

    var body: some View {
        if module.nowPlaying.isActive {
            activeContent
        } else {
            emptyState
        }
    }

    // MARK: — Active layout (artwork left, info + controls right)

    private var activeContent: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 14) {
                artworkView

                VStack(alignment: .leading, spacing: 4) {
                    if let title = module.nowPlaying.title {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                    }
                    if let artist = module.nowPlaying.artist {
                        Text(artist)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    controlsView
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 72)

            VStack(spacing: 4) {
                scrubbableBar

                HStack {
                    Text(formatTime(module.nowPlaying.elapsed))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text(formatTime(module.nowPlaying.duration))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var scrubbableBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.18))
                    .frame(height: 4)
                Capsule()
                    .fill(.white.opacity(0.85))
                    .frame(width: max(0, geo.size.width * module.nowPlaying.progress), height: 4)
            }
            .frame(maxHeight: .infinity) // centre la barre dans la zone tactile
            .contentShape(Rectangle()) // toute la hauteur est cliquable
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard module.nowPlaying.duration > 0, geo.size.width > 0 else { return }
                        let fraction = max(0, min(1, value.location.x / geo.size.width))
                        module.previewElapsed(fraction * module.nowPlaying.duration)
                    }
                    .onEnded { value in
                        guard module.nowPlaying.duration > 0, geo.size.width > 0 else { return }
                        let fraction = max(0, min(1, value.location.x / geo.size.width))
                        module.seek(to: fraction * module.nowPlaying.duration)
                    }
            )
        }
        .frame(height: 16) // zone de glissement haute de 16 px
    }

    @ViewBuilder
    private var artworkView: some View {
        if let artwork = module.nowPlaying.artwork {
            Image(nsImage: artwork)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.4), radius: 4)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.06))
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: "music.note")
                        .imageScale(.large)
                        .foregroundStyle(.quaternary)
                }
        }
    }

    private var controlsView: some View {
        HStack(spacing: 20) {
            mediaButton(icon: "backward.fill", size: 15) { module.send(.previousTrack) }
            mediaButton(
                icon: module.nowPlaying.isPlaying ? "pause.fill" : "play.fill",
                size: 18
            ) {
                module.send(.togglePlayPause)
            }
            mediaButton(icon: "forward.fill", size: 15) { module.send(.nextTrack) }
        }
    }

    private func mediaButton(icon: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }

    // MARK: — Empty

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note")
                .imageScale(.large)
                .foregroundStyle(.quaternary)
            Text("media.nowPlaying.empty", bundle: localizationBundle)
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: — Helpers

    private func formatTime(_ time: TimeInterval) -> String {
        guard time > 0 else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}
