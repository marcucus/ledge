import AppKit

final class MediaRemoteSource: MediaSource {
    private typealias GetInfoFn = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    private typealias SendCommandFn = @convention(c) (Int32, AnyObject?) -> Bool
    private typealias RegisterFn = @convention(c) (DispatchQueue) -> Void
    private typealias SetElapsedFn = @convention(c) (Double) -> Void

    private let mrHandle: UnsafeMutableRawPointer?

    init() {
        mrHandle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)
        if let handle = mrHandle, let ptr = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") {
            unsafeBitCast(ptr, to: RegisterFn.self)(DispatchQueue.main)
        }
    }

    func fetchNowPlayingInfo() async -> MediaState {
        guard let handle = mrHandle, let ptr = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") else { return .empty }
        let getInfo = unsafeBitCast(ptr, to: GetInfoFn.self)
        return await withCheckedContinuation { continuation in
            getInfo(DispatchQueue.main) { info in
                guard !info.isEmpty else { continuation.resume(returning: .empty); return }
                let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String
                let artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String
                let album = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String
                let elapsed = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? TimeInterval ?? 0
                let duration = info["kMRMediaRemoteNowPlayingInfoDuration"] as? TimeInterval ?? 0
                let isPlaying = (info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0) > 0
                let artwork = (info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data)
                    .flatMap(NSImage.init(data:))
                let shuffleMode = info["kMRMediaRemoteNowPlayingInfoShuffleMode"] as? Int ?? 0
                let repeatMode = info["kMRMediaRemoteNowPlayingInfoRepeatMode"] as? Int ?? 0
                continuation.resume(returning: MediaState(
                    title: title, artist: artist, album: album,
                    artwork: artwork, isPlaying: isPlaying,
                    elapsed: elapsed, duration: duration,
                    shuffleMode: shuffleMode, repeatMode: repeatMode
                ))
            }
        }
    }

    func send(_ command: MediaCommand) async {
        guard let handle = mrHandle else { return }
        // Seek : API dédiée MRMediaRemoteSetElapsedTime (fiable, fonctionne avec Apple Music)
        if case let .seek(position) = command {
            if let ptr = dlsym(handle, "MRMediaRemoteSetElapsedTime") {
                unsafeBitCast(ptr, to: SetElapsedFn.self)(position)
            }
            return
        }
        guard let ptr = dlsym(handle, "MRMediaRemoteSendCommand") else { return }
        _ = unsafeBitCast(ptr, to: SendCommandFn.self)(command.mrCode, nil)
    }

    deinit { if let handle = mrHandle { dlclose(handle) } }
}

private extension MediaCommand {
    var mrCode: Int32 {
        switch self {
        case .togglePlayPause: 2
        case .nextTrack: 4
        case .previousTrack: 5
        case .seek: 45
        case .toggleShuffle: 6
        case .toggleRepeat: 7
        }
    }
}
