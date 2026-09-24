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

    // MARK: — Active layout

    private var activeContent: some View {
        HStack(alignment: .top, spacing: 16) {
            artworkView

            VStack(alignment: .leading, spacing: 4) {
                // Ligne 1 : Artist · Album
                HStack(spacing: 4) {
                    if let artist = module.nowPlaying.artist {
                        Text(artist)
                            .foregroundStyle(module.artworkAccentColor)
                    }
                    if module.nowPlaying.artist != nil, module.nowPlaying.album != nil {
                        Text("·").foregroundStyle(.quaternary)
                    }
                    if let album = module.nowPlaying.album {
                        Text(album).foregroundStyle(.tertiary)
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)

                // Ligne 2 : Titre
                if let title = module.nowPlaying.title {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                // Ligne 3 : [⇄] [◀◀] [▶] [▶▶] [↺]
                controlsView

                // Ligne 4 : 0:23 ━━━━━━━━━━━━ 3:42
                progressRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 80)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: — Controls (toutes les 5 en une ligne)

    private var controlsView: some View {
        HStack(spacing: 14) {
            toggleButton(
                icon: "shuffle",
                active: module.nowPlaying.shuffleMode > 0
            ) { module.send(.toggleShuffle) }

            mediaButton(icon: "backward.fill", size: 14) { module.send(.previousTrack) }

            mediaButton(
                icon: module.nowPlaying.isPlaying ? "pause.fill" : "play.fill",
                size: 18
            ) { module.send(.togglePlayPause) }

            mediaButton(icon: "forward.fill", size: 14) { module.send(.nextTrack) }

            toggleButton(
                icon: module.nowPlaying.repeatMode == 1 ? "repeat.1" : "repeat",
                active: module.nowPlaying.repeatMode > 0
            ) { module.send(.toggleRepeat) }
        }
    }

    // MARK: — Progress row : timestamp ━━━━━━━━━ timestamp

    private var progressRow: some View {
        HStack(spacing: 6) {
            Text(formatTime(module.nowPlaying.elapsed))
                .font(.system(size: 9).monospacedDigit())
                .foregroundStyle(.tertiary)
                .fixedSize()

            scrubbableBar

            Text(formatTime(module.nowPlaying.duration))
                .font(.system(size: 9).monospacedDigit())
                .foregroundStyle(.tertiary)
                .fixedSize()
        }
        .frame(height: 12)
    }

    private var scrubbableBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.12))
                    .frame(height: 3)
                let fillWidth = max(0, geo.size.width * module.nowPlaying.progress)
                Capsule()
                    .fill(module.artworkAccentColor)
                    .frame(width: fillWidth, height: 3)
                    .shadow(color: module.artworkAccentColor.opacity(0.6), radius: 3)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
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
    }

    // MARK: — Artwork

    @ViewBuilder
    private var artworkView: some View {
        if let artwork = module.nowPlaying.artwork {
            Image(nsImage: artwork)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: module.artworkAccentColor.opacity(0.5), radius: 14, x: 0, y: 4)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.06))
                .frame(width: 80, height: 80)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 24))
                        .foregroundStyle(.quaternary)
                }
        }
    }

    // MARK: — Boutons

    private func mediaButton(icon: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 28, height: 26)
        }
        .buttonStyle(.plain)
    }

    /// Bouton toggle (shuffle / repeat) : fond coloré + icône accentuée quand actif.
    private func toggleButton(icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: active ? .semibold : .regular))
                .foregroundStyle(active ? module.artworkAccentColor : Color.primary.opacity(0.3))
                .frame(width: 28, height: 26)
                .background {
                    if active {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(module.artworkAccentColor.opacity(0.15))
                    }
                }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: active)
    }

    // MARK: — Empty

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note")
                .font(.system(size: 28))
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
