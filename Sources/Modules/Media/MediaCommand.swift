import Foundation

public enum MediaCommand {
    case togglePlayPause
    case nextTrack
    case previousTrack
    case seek(to: TimeInterval)
    case toggleShuffle
    case toggleRepeat
}
