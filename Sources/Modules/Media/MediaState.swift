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

    public init(
        title: String?, artist: String?, album: String?,
        artwork: NSImage?, isPlaying: Bool,
        elapsed: TimeInterval, duration: TimeInterval,
        shuffleMode: Int, repeatMode: Int
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.artwork = artwork
        self.isPlaying = isPlaying
        self.elapsed = elapsed
        self.duration = duration
        self.shuffleMode = shuffleMode
        self.repeatMode = repeatMode
    }

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

    /// Fusionne un état fraîchement récupéré (`incoming`, ex. via MediaRemote) avec l'état
    /// précédent (`previous`, ex. mis à jour par la notification distribuée Apple Music) :
    /// comble les champs que la source actuelle ne fournit pas, à condition qu'il s'agisse
    /// toujours du même morceau (même titre).
    public static func merging(incoming: MediaState, previous: MediaState) -> MediaState {
        var merged = incoming.isActive ? incoming : previous
        // Préserve l'écoulé du minuteur de la notification distribuée si la source actuelle n'en a pas.
        if incoming.isActive, incoming.elapsed == 0, previous.elapsed > 0, previous.title == merged.title {
            merged.elapsed = previous.elapsed
        }
        // Conserve la pochette déjà récupérée si la source actuelle n'en fournit pas (cas Apple Music).
        if merged.artwork == nil, previous.artwork != nil, previous.title == merged.title {
            merged.artwork = previous.artwork
        }
        // Préserve shuffle/repeat depuis la notification Apple Music si la source actuelle ne les expose pas.
        if merged.shuffleMode == 0, previous.shuffleMode != 0, previous.title == merged.title {
            merged.shuffleMode = previous.shuffleMode
        }
        if merged.repeatMode == 0, previous.repeatMode != 0, previous.title == merged.title {
            merged.repeatMode = previous.repeatMode
        }
        return merged
    }
}
