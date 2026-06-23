import AppKit

public struct MediaState {
    public var title: String?
    public var artist: String?
    public var album: String?
    public var artwork: NSImage?
    public var isPlaying: Bool
    public var elapsed: TimeInterval
    public var duration: TimeInterval
    public var shuffleMode: Int  // 0 = off, 1+ = on
    public var repeatMode: Int   // 0 = off, 1 = one, 2 = all

    public static let empty = MediaState(
        title: nil, artist: nil, album: nil,
        artwork: nil, isPlaying: false,
        elapsed: 0, duration: 0,
        shuffleMode: 0, repeatMode: 0
    )

    public var isActive: Bool {
        title != nil
    }

    public var progress: Double {
        guard duration > 0 else { return 0 }
        return min(elapsed / duration, 1)
    }
}
