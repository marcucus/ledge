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

    private var activeContent: some View {
        VStack(spacing: 12) {
            artworkView
            metadataView
            progressBar
            controlsView
        }
        .padding(16)
    }

    @ViewBuilder
    private var artworkView: some View {
        if let artwork = module.nowPlaying.artwork {
            Image(nsImage: artwork)
                .resizable().scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 4)
        } else {
            RoundedRectangle(cornerRadius: 8).fill(.quaternary)
                .frame(width: 120, height: 120)
        }
    }

    private var metadataView: some View {
        VStack(spacing: 2) {
            if let title = module.nowPlaying.title {
                Text(title).font(.headline).lineLimit(1)
            }
            if let artist = module.nowPlaying.artist {
                Text(artist).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }

    private var progressBar: some View {
        ProgressView(value: module.nowPlaying.progress)
            .progressViewStyle(.linear)
            .tint(.primary)
    }

    private var controlsView: some View {
        HStack(spacing: 24) {
            mediaButton(icon: "backward.fill") { module.send(.previousTrack) }
            mediaButton(icon: module.nowPlaying.isPlaying ? "pause.fill" : "play.fill") {
                module.send(.togglePlayPause)
            }
            mediaButton(icon: "forward.fill") { module.send(.nextTrack) }
        }
    }

    private func mediaButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).imageScale(.large).frame(width: 36, height: 36)
        }.buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note").imageScale(.large).foregroundStyle(.quaternary)
            Text("media.nowPlaying.empty").font(.callout).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
