import AppKit
@testable import MediaModule
import Testing

struct MediaStateMergeTests {
    private func makeState(
        title: String? = nil,
        elapsed: TimeInterval = 0,
        artworkPresent: Bool = false,
        shuffleMode: Int = 0,
        repeatMode: Int = 0
    ) -> MediaState {
        MediaState(
            title: title, artist: nil, album: nil,
            artwork: artworkPresent ? NSImage() : nil,
            isPlaying: true,
            elapsed: elapsed, duration: 200,
            shuffleMode: shuffleMode, repeatMode: repeatMode
        )
    }

    @Test func incomingActiveStateWins() {
        let previous = makeState(title: "Old Song")
        let incoming = makeState(title: "New Song", elapsed: 10)
        let merged = MediaState.merging(incoming: incoming, previous: previous)
        #expect(merged.title == "New Song")
        #expect(merged.elapsed == 10)
    }

    @Test func inactiveIncomingFallsBackToPrevious() {
        let previous = makeState(title: "Still Playing")
        let incoming = MediaState.empty // titre nil → isActive == false
        let merged = MediaState.merging(incoming: incoming, previous: previous)
        #expect(merged.title == "Still Playing")
    }

    @Test func preservesElapsedWhenIncomingHasNoneForSameTrack() {
        let previous = makeState(title: "Track", elapsed: 42)
        let incoming = makeState(title: "Track", elapsed: 0)
        let merged = MediaState.merging(incoming: incoming, previous: previous)
        #expect(merged.elapsed == 42)
    }

    @Test func doesNotPreserveElapsedAcrossDifferentTracks() {
        let previous = makeState(title: "Track A", elapsed: 42)
        let incoming = makeState(title: "Track B", elapsed: 0)
        let merged = MediaState.merging(incoming: incoming, previous: previous)
        #expect(merged.elapsed == 0)
    }

    @Test func preservesArtworkForSameTrackWhenIncomingHasNone() {
        let previous = makeState(title: "Track", artworkPresent: true)
        let incoming = makeState(title: "Track", artworkPresent: false)
        let merged = MediaState.merging(incoming: incoming, previous: previous)
        #expect(merged.artwork != nil)
    }

    @Test func preservesShuffleAndRepeatForSameTrack() {
        let previous = makeState(title: "Track", shuffleMode: 1, repeatMode: 2)
        let incoming = makeState(title: "Track", shuffleMode: 0, repeatMode: 0)
        let merged = MediaState.merging(incoming: incoming, previous: previous)
        #expect(merged.shuffleMode == 1)
        #expect(merged.repeatMode == 2)
    }
}
