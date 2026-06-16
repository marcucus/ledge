import AppKit

final class MediaRemoteSource: MediaSource {
    private typealias GetInfoFn     = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    private typealias SendCommandFn = @convention(c) (Int32, AnyObject?) -> Bool
    private typealias RegisterFn    = @convention(c) (DispatchQueue) -> Void
    private typealias SetElapsedFn  = @convention(c) (Double) -> Void

    private let mrHandle: UnsafeMutableRawPointer?

    init() {
        mrHandle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)
        if let h = mrHandle, let ptr = dlsym(h, "MRMediaRemoteRegisterForNowPlayingNotifications") {
            unsafeBitCast(ptr, to: RegisterFn.self)(DispatchQueue.main)
        }
    }

    func fetchNowPlayingInfo() async -> MediaState {
        guard let h = mrHandle, let ptr = dlsym(h, "MRMediaRemoteGetNowPlayingInfo") else { return .empty }
        let fn = unsafeBitCast(ptr, to: GetInfoFn.self)
        return await withCheckedContinuation { continuation in
            fn(DispatchQueue.main) { info in
                guard !info.isEmpty else { continuation.resume(returning: .empty); return }
                let title     = info["kMRMediaRemoteNowPlayingInfoTitle"]         as? String
                let artist    = info["kMRMediaRemoteNowPlayingInfoArtist"]        as? String
                let album     = info["kMRMediaRemoteNowPlayingInfoAlbum"]         as? String
                let elapsed   = info["kMRMediaRemoteNowPlayingInfoElapsedTime"]   as? TimeInterval ?? 0
                let duration  = info["kMRMediaRemoteNowPlayingInfoDuration"]      as? TimeInterval ?? 0
                let isPlaying = (info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0) > 0
                let artwork   = (info["kMRMediaRemoteNowPlayingInfoArtworkData"]  as? Data)
                    .flatMap(NSImage.init(data:))
                continuation.resume(returning: MediaState(
                    title: title, artist: artist, album: album,
                    artwork: artwork, isPlaying: isPlaying,
                    elapsed: elapsed, duration: duration
                ))
            }
        }
    }

    func send(_ command: MediaCommand) async {
        guard let h = mrHandle else { return }
        // Seek : API dédiée MRMediaRemoteSetElapsedTime (fiable, fonctionne avec Apple Music)
        if case .seek(let position) = command {
            if let ptr = dlsym(h, "MRMediaRemoteSetElapsedTime") {
                unsafeBitCast(ptr, to: SetElapsedFn.self)(position)
            }
            return
        }
        guard let ptr = dlsym(h, "MRMediaRemoteSendCommand") else { return }
        _ = unsafeBitCast(ptr, to: SendCommandFn.self)(command.mrCode, nil)
    }

    deinit { if let h = mrHandle { dlclose(h) } }
}

private extension MediaCommand {
    var mrCode: Int32 {
        switch self {
        case .togglePlayPause: return 2
        case .nextTrack:       return 4
        case .previousTrack:   return 5
        case .seek:            return 45
        }
    }
}
