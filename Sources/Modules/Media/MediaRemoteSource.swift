import AppKit

final class MediaRemoteSource: MediaSource {
    private typealias GetInfoFn     = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    private typealias SendCommandFn = @convention(c) (Int32, AnyObject?) -> Bool
    private typealias RegisterFn    = @convention(c) (DispatchQueue) -> Void

    private let bundle: CFBundle?

    init() {
        let url = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
        bundle = CFBundleCreate(nil, url as CFURL)

        // Indispensable : sans cet appel, kMRMediaRemoteNowPlayingInfoDidChangeNotification
        // n'est jamais envoyé par le système.
        if let b = bundle,
           let ptr = CFBundleGetFunctionPointerForName(b, "MRMediaRemoteRegisterForNowPlayingNotifications" as CFString) {
            let fn = unsafeBitCast(ptr, to: RegisterFn.self)
            fn(DispatchQueue.main)
        }
    }

    func fetchNowPlayingInfo() async -> MediaState {
        guard let bundle,
              let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString)
        else { return .empty }

        let fn = unsafeBitCast(ptr, to: GetInfoFn.self)
        return await withCheckedContinuation { continuation in
            fn(DispatchQueue.main) { info in
                let title    = info["kMRMediaRemoteNowPlayingInfoTitle"]   as? String
                let artist   = info["kMRMediaRemoteNowPlayingInfoArtist"]  as? String
                let album    = info["kMRMediaRemoteNowPlayingInfoAlbum"]   as? String
                let elapsed  = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? TimeInterval ?? 0
                let duration = info["kMRMediaRemoteNowPlayingInfoDuration"]    as? TimeInterval ?? 0
                let isPlaying = (info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0) > 0
                let artwork  = (info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data)
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
        guard let bundle,
              let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString)
        else { return }
        let fn = unsafeBitCast(ptr, to: SendCommandFn.self)
        _ = fn(command.mrCode, nil)
    }
}

private extension MediaCommand {
    var mrCode: Int32 {
        switch self {
        case .togglePlayPause: 2
        case .nextTrack:       4
        case .previousTrack:   5
        }
    }
}
