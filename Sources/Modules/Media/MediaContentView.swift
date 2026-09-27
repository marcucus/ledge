import Core
import SwiftUI

struct MediaContentView: View {
    var module: MediaModule
    @Environment(\.panelComposition) private var composition

    var body: some View {
        if module.nowPlaying.isActive {
            activeContent
        } else {
            emptyState
        }
    }

    // MARK: — Composition layouts

    @ViewBuilder
    private var activeContent: some View {
        switch composition {
        case .focused:
            focusedContent
        case .panoramic:
            panoramicContent
        case .immersive:
            immersiveContent
        }
    }

    /// Concentrée : toutes les actions restent dans un bloc court, lisible d'un regard.
    private var focusedContent: some View {
        HStack(spacing: 18) {
            artworkView(size: 118, cornerRadius: 12)

            VStack(alignment: .leading, spacing: 10) {
                trackMetadata(titleSize: 18)
                Spacer(minLength: 0)
                progressRow
                controlsView(spacing: 12, prominentPlayButton: false)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// Panoramique : pochette, informations et commandes occupent trois zones horizontales.
    private var panoramicContent: some View {
        HStack(spacing: 24) {
            artworkView(size: 150, cornerRadius: 14)

            VStack(alignment: .leading, spacing: 10) {
                trackMetadata(titleSize: 21)
                Spacer(minLength: 8)
                progressRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 1, height: 112)

            controlsView(spacing: 16, prominentPlayButton: true)
                .frame(width: 220)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Immersive : la pochette devient le point focal et la typographie prend une vraie échelle.
    private var immersiveContent: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 24) {
                artworkView(size: 176, cornerRadius: 16)

                VStack(alignment: .leading, spacing: 12) {
                    trackMetadata(titleSize: 24)
                    Spacer(minLength: 8)
                    progressRow
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)

            controlsView(spacing: 28, prominentPlayButton: true)
                .frame(height: 72)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: — Track information

    private func trackMetadata(titleSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
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

            if let title = module.nowPlaying.title {
                Text(title)
                    .font(.system(size: titleSize, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private extension MediaContentView {

    // MARK: — Controls

    private func controlsView(spacing: CGFloat, prominentPlayButton: Bool) -> some View {
        HStack(spacing: spacing) {
            toggleButton(
                icon: "shuffle",
                labelKey: "media.action.shuffle",
                active: module.nowPlaying.shuffleMode > 0
            ) {
                module.send(.toggleShuffle)
            }
            mediaButton(icon: "backward.fill", labelKey: "media.action.previous", size: 15) {
                module.send(.previousTrack)
            }

            if prominentPlayButton {
                playButton
            } else {
                mediaButton(
                    icon: module.nowPlaying.isPlaying ? "pause.fill" : "play.fill",
                    labelKey: module.nowPlaying.isPlaying ? "media.action.pause" : "media.action.play",
                    size: 19
                ) { module.send(.togglePlayPause) }
            }

            mediaButton(icon: "forward.fill", labelKey: "media.action.next", size: 15) {
                module.send(.nextTrack)
            }
            toggleButton(
                icon: module.nowPlaying.repeatMode == 1 ? "repeat.1" : "repeat",
                labelKey: "media.action.repeat",
                active: module.nowPlaying.repeatMode > 0
            ) { module.send(.toggleRepeat) }
        }
        .frame(maxWidth: .infinity)
    }

    private var playButton: some View {
        Button { module.send(.togglePlayPause) } label: {
            Image(systemName: module.nowPlaying.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .overlay {
                    Circle().stroke(Color.white.opacity(0.72), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            Text(
                module.nowPlaying.isPlaying ? "media.action.pause" : "media.action.play",
                bundle: localizationBundle
            )
        )
    }

    private func mediaButton(
        icon: String,
        labelKey: String,
        size: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey(labelKey), bundle: localizationBundle))
    }

    private func toggleButton(
        icon: String,
        labelKey: String,
        active: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: active ? .semibold : .regular))
                .foregroundStyle(active ? module.artworkAccentColor : Color.white.opacity(0.34))
                .frame(width: 30, height: 30)
                .background {
                    if active {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(module.artworkAccentColor.opacity(0.14))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey(labelKey), bundle: localizationBundle))
        .accessibilityValue(
            active
                ? Text("accessibility.enabled", bundle: localizationBundle)
                : Text("accessibility.disabled", bundle: localizationBundle)
        )
        .animation(.easeInOut(duration: 0.15), value: active)
    }

    // MARK: — Progress

    private var progressRow: some View {
        HStack(spacing: 8) {
            timestamp(module.nowPlaying.elapsed)
            scrubbableBar
            timestamp(module.nowPlaying.duration)
        }
        .frame(height: 16)
    }

    private func timestamp(_ time: TimeInterval) -> some View {
        Text(formatTime(time))
            .font(.system(size: 10).monospacedDigit())
            .foregroundStyle(.tertiary)
            .fixedSize()
    }

    private var scrubbableBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.14))
                    .frame(height: 3)
                Capsule()
                    .fill(module.artworkAccentColor)
                    .frame(width: max(0, geometry.size.width * module.nowPlaying.progress), height: 3)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(scrubGesture(width: geometry.size.width))
        }
    }

    private func scrubGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard module.nowPlaying.duration > 0, width > 0 else { return }
                let fraction = max(0, min(1, value.location.x / width))
                module.previewElapsed(fraction * module.nowPlaying.duration)
            }
            .onEnded { value in
                guard module.nowPlaying.duration > 0, width > 0 else { return }
                let fraction = max(0, min(1, value.location.x / width))
                module.seek(to: fraction * module.nowPlaying.duration)
            }
    }

    // MARK: — Artwork

    @ViewBuilder
    private func artworkView(size: CGFloat, cornerRadius: CGFloat) -> some View {
        if let artwork = module.nowPlaying.artwork {
            Image(nsImage: artwork)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                }
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.white.opacity(0.06))
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.28, weight: .light))
                        .foregroundStyle(.quaternary)
                }
        }
    }

    // MARK: — Empty

    private var emptyState: some View {
        ModuleEmptyState(
            icon: "music.note",
            titleKey: "media.nowPlaying.empty",
            detailKey: "media.nowPlaying.empty.detail"
        )
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard time > 0 else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}
