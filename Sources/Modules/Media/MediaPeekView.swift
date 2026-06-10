import SwiftUI

struct MediaPeekView: View {
    var module: MediaModule

    var body: some View {
        HStack(spacing: 10) {
            artworkView
            trackInfo
            Spacer()
            playPauseButton
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var artworkView: some View {
        if let artwork = module.nowPlaying.artwork {
            Image(nsImage: artwork)
                .resizable().scaledToFill()
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            RoundedRectangle(cornerRadius: 4).fill(.quaternary)
                .frame(width: 28, height: 28)
        }
    }

    private var trackInfo: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let title = module.nowPlaying.title {
                Text(title).font(.caption.weight(.medium)).lineLimit(1)
            } else {
                Text("media.nowPlaying.empty").font(.caption).foregroundStyle(.secondary)
            }
            if let artist = module.nowPlaying.artist {
                Text(artist).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }

    private var playPauseButton: some View {
        Button { module.send(.togglePlayPause) } label: {
            Image(systemName: module.nowPlaying.isPlaying ? "pause.fill" : "play.fill")
                .imageScale(.small).foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .opacity(module.nowPlaying.isActive ? 1 : 0)
    }
}
