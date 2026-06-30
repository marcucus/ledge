import AppKit
import Core
import SwiftUI

@MainActor @Observable public final class MediaModule: NotchModule {
    public let id = "media"
    public let tabIcon = "music.note"
    public let tabLabel: LocalizedStringKey = "module.media.label"

    public private(set) var nowPlaying: MediaState = .empty
    public var onBecameActive: (() -> Void)?
    public var onAmbientUpdate: ((AmbientContent?) -> Void)?

    private let source: any MediaSource
    private let artworkSource = AppleMusicArtworkSource()
    private let spotifyArtworkSource = SpotifyArtworkSource()
    @ObservationIgnored private nonisolated(unsafe) var mrObserver: NSObjectProtocol?
    @ObservationIgnored private nonisolated(unsafe) var pollTimer: Timer?
    @ObservationIgnored private nonisolated(unsafe) var elapsedTimer: Timer?
    @ObservationIgnored private nonisolated(unsafe) var resyncTimer: Timer?
    @ObservationIgnored private var startupPollAttemptsRemaining = MediaModule.maxStartupPollAttempts
    @ObservationIgnored private var wasActive = false
    @ObservationIgnored private var cachedArtwork: NSImage?
    @ObservationIgnored private var cachedArtworkColor: Color = .white
    public var artworkAccentColor: Color { cachedArtworkColor }
    /// True quand la lecture est pilotée par Apple Music (notification distribuée).
    @ObservationIgnored private var sourceIsAppleMusic = false
    @ObservationIgnored private var sourceIsSpotify = false

    public init() {
        source = MediaRemoteSource()
    }

    public func start() {
        // MediaRemote — Spotify, navigateurs, etc.
        mrObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
            object: nil, queue: .main
        ) { [weak self] _ in Task { [weak self] in await self?.refresh() } }

        // com.apple.Music.playerInfo — distributed notification, aucun droit requis.
        // suspensionBehavior .deliverImmediately garantit la réception même en arrière-plan.
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleMusicPlayerInfo(_:)),
            name: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )

        scheduleStartupPoll()
        Task { await refresh() }
    }

    /// Sonde de démarrage à intervalles espacés (utile si la musique joue déjà au lancement —
    /// les notifications ne couvrent que les changements survenant après l'abonnement).
    /// Nombre de tentatives borné : aucun polling au repos une fois la fenêtre passée.
    private static let maxStartupPollAttempts = 3

    private func scheduleStartupPoll() {
        guard startupPollAttemptsRemaining > 0 else { return }
        startupPollAttemptsRemaining -= 1
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
                self?.scheduleStartupPoll()
            }
        }
    }

    @objc private func handleMusicPlayerInfo(_ notif: Notification) {
        guard let info = notif.userInfo else { return }
        let playerState = info["Player State"] as? String ?? ""
        let isPlaying = playerState == "Playing"
        let isActive = playerState == "Playing" || playerState == "Paused"
        let newTitle = isActive ? info["Name"] as? String : nil

        let state = MediaState(
            title: newTitle,
            artist: isActive ? info["Artist"] as? String : nil,
            album: isActive ? info["Album"] as? String : nil,
            // Only keep existing artwork if the track title hasn't changed.
            // If the title changed, clear it so fetchAppleMusicArtworkIfNeeded() fetches the new one.
            artwork: isActive && newTitle == nowPlaying.title ? nowPlaying.artwork : nil,
            isPlaying: isPlaying,
            // La notif Apple Music ne contient souvent pas « Current Position » : sur le même
            // morceau on conserve l'elapsed courant (sinon la barre saute à 0 à chaque play/pause).
            elapsed: (info["Current Position"] as? Double) ?? (newTitle == nowPlaying.title ? nowPlaying.elapsed : 0),
            duration: (info["Total Time"] as? Double ?? 0) / 1000,
            shuffleMode: isActive ? (info["Shuffle Mode"] as? Int ?? nowPlaying.shuffleMode) : 0,
            repeatMode: isActive ? (info["Repeat Mode"] as? Int ?? nowPlaying.repeatMode) : 0
        )
        let becameActive = !wasActive && state.isActive
        wasActive = state.isActive
        sourceIsAppleMusic = state.isActive
        sourceIsSpotify = false
        nowPlaying = state
        if becameActive { onBecameActive?() }
        updateElapsedTimer()
        fetchAppleMusicArtworkIfNeeded()
        updateAmbient()

        // Refresh complet pour récupérer la pochette via MediaRemote
        Task { await refresh() }
    }

    private func refresh() async {
        let state = await source.fetchNowPlayingInfo()
        let merged = MediaState.merging(incoming: state, previous: nowPlaying)
        let becameActive = !wasActive && merged.isActive
        let playStateChanged = merged.isPlaying != nowPlaying.isPlaying
        wasActive = merged.isActive
        // Detect Spotify: running and NOT Apple Music
        if merged.isActive, !sourceIsAppleMusic {
            sourceIsSpotify = NSWorkspace.shared.runningApplications
                .contains { $0.bundleIdentifier == "com.spotify.client" }
        } else if !merged.isActive {
            sourceIsSpotify = false
        }
        nowPlaying = merged
        if becameActive { onBecameActive?() }
        if playStateChanged { updateElapsedTimer() }
        fetchAppleMusicArtworkIfNeeded()
        fetchSpotifyArtworkIfNeeded()
        updateAmbient()
    }

    /// Apple Music ne fournit pas la pochette via MediaRemote → on la récupère via AppleScript.
    private func fetchAppleMusicArtworkIfNeeded() {
        guard sourceIsAppleMusic, nowPlaying.artwork == nil, let title = nowPlaying.title else { return }
        let key = "\(title)|\(nowPlaying.artist ?? "")"
        Task { [weak self] in
            guard let image = await self?.artworkSource.artwork(forTrackKey: key) else { return }
            guard let self, nowPlaying.title == title else { return }
            nowPlaying.artwork = image
            updateAmbient()
        }
    }

    /// Spotify peut ne pas fournir de pochette via MediaRemote → fallback via AppleScript (artwork url).
    private func fetchSpotifyArtworkIfNeeded() {
        guard sourceIsSpotify, nowPlaying.artwork == nil, let title = nowPlaying.title else { return }
        let key = "\(title)|\(nowPlaying.artist ?? "")"
        Task { [weak self] in
            guard let image = await self?.spotifyArtworkSource.artwork(forTrackKey: key) else { return }
            guard let self, nowPlaying.title == title, nowPlaying.artwork == nil else { return }
            nowPlaying.artwork = image
            updateAmbient()
        }
    }

    private func updateAmbient() {
        if nowPlaying.isActive {
            let artwork = nowPlaying.artwork
            // Recompute color only when artwork reference changes
            if artwork !== cachedArtwork {
                cachedArtwork = artwork
                cachedArtworkColor = artwork?.dominantColor ?? .white
            }
            onAmbientUpdate?(.init(
                kind: .music(
                    artwork: artwork,
                    isPlaying: nowPlaying.isPlaying,
                    elapsed: nowPlaying.elapsed,
                    duration: nowPlaying.duration
                ),
                accentColor: cachedArtworkColor
            ))
        } else {
            cachedArtwork = nil
            onAmbientUpdate?(nil)
        }
    }

    public func send(_ command: MediaCommand) {
        // Mise à jour optimiste : l'UI reflète le changement immédiatement sans attendre
        // la prochaine notification MediaRemote.
        switch command {
        case .toggleShuffle:
            nowPlaying.shuffleMode = nowPlaying.shuffleMode > 0 ? 0 : 1
        case .toggleRepeat:
            // Cycle : off(0) → all(2) → one(1) → off(0)
            switch nowPlaying.repeatMode {
            case 0:  nowPlaying.repeatMode = 2
            case 2:  nowPlaying.repeatMode = 1
            default: nowPlaying.repeatMode = 0
            }
        default:
            break
        }
        Task { await source.send(command) }
    }

    /// Aperçu visuel pendant le glissement (ne pilote pas encore le lecteur).
    public func previewElapsed(_ position: TimeInterval) {
        nowPlaying.elapsed = max(0, min(position, nowPlaying.duration))
    }

    /// Positionne réellement la lecture (à appeler à la fin du glissement).
    public func seek(to position: TimeInterval) {
        let target = max(0, min(position, nowPlaying.duration))
        let previousElapsed = nowPlaying.elapsed
        nowPlaying.elapsed = target
        if sourceIsAppleMusic {
            seekAppleMusic(to: target, revertTo: previousElapsed)
        } else {
            send(.seek(to: target))
        }
    }

    private func seekAppleMusic(to position: TimeInterval, revertTo previousElapsed: TimeInterval) {
        let running = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.apple.Music"
        }
        guard running else {
            nowPlaying.elapsed = previousElapsed
            return
        }
        Task.detached { [weak self] in
            let succeeded = AppleMusicScriptingBridge.setPlayerPosition(position)
            guard !succeeded else { return }
            let ref = self
            await MainActor.run { ref?.nowPlaying.elapsed = previousElapsed }
        }
    }

    // MARK: — Elapsed timer

    private func updateElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        resyncTimer?.invalidate()
        resyncTimer = nil
        guard nowPlaying.isPlaying else { return }
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, nowPlaying.isPlaying else { return }
                nowPlaying.elapsed = min(nowPlaying.elapsed + 1, nowPlaying.duration)
            }
        }
        // Resync Apple Music position every 5 s to prevent drift from the 1-s ticker.
        if sourceIsAppleMusic {
            resyncTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
                Task { [weak self] in await self?.resyncAppleMusicElapsed() }
            }
        }
    }

    private func resyncAppleMusicElapsed() async {
        guard sourceIsAppleMusic, nowPlaying.isPlaying else { return }
        guard let pos = await appleMusicPlayerPosition() else { return }
        guard sourceIsAppleMusic, nowPlaying.isPlaying else { return }
        nowPlaying.elapsed = pos
    }

    private nonisolated func appleMusicPlayerPosition() async -> Double? {
        await Task.detached { AppleMusicScriptingBridge.playerPosition() }.value
    }

    public func stop() {
        mrObserver.map { NotificationCenter.default.removeObserver($0) }
        mrObserver = nil
        DistributedNotificationCenter.default().removeObserver(
            self,
            name: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil
        )
        pollTimer?.invalidate()
        pollTimer = nil
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        resyncTimer?.invalidate()
        resyncTimer = nil
    }

    public func makePeekView() -> AnyView {
        AnyView(MediaPeekView(module: self))
    }

    public func makeContentView() -> AnyView {
        AnyView(MediaContentView(module: self))
    }

    deinit {
        mrObserver.map { NotificationCenter.default.removeObserver($0) }
        DistributedNotificationCenter.default().removeObserver(self)
        pollTimer?.invalidate()
        elapsedTimer?.invalidate()
        resyncTimer?.invalidate()
    }
}
