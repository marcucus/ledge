import AppKit
import SwiftUI
import Core

@MainActor @Observable public final class MediaModule: NotchModule {
    public let id = "media"
    public let tabIcon = "music.note"
    public let tabLabel: LocalizedStringKey = "module.media.label"

    public private(set) var nowPlaying: MediaState = .empty
    public var onBecameActive: (() -> Void)?

    private let source: any MediaSource
    @ObservationIgnored nonisolated(unsafe) private var mrObserver: NSObjectProtocol?
    @ObservationIgnored nonisolated(unsafe) private var pollTimer: Timer?
    @ObservationIgnored nonisolated(unsafe) private var elapsedTimer: Timer?
    @ObservationIgnored private var wasActive = false
    /// True quand la lecture est pilotée par Apple Music (notification distribuée).
    @ObservationIgnored private var sourceIsAppleMusic = false

    public init() { source = MediaRemoteSource() }

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

        // Polling de secours toutes les 3 s (utile si la musique joue déjà au lancement)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { [weak self] in await self?.refresh() }
        }

        Task { await refresh() }
    }

    @objc private func handleMusicPlayerInfo(_ notif: Notification) {
        guard let info = notif.userInfo else { return }
        let playerState = info["Player State"] as? String ?? ""
        let isPlaying   = playerState == "Playing"
        let isActive    = playerState == "Playing" || playerState == "Paused"

        let state = MediaState(
            title:     isActive ? info["Name"]   as? String : nil,
            artist:    isActive ? info["Artist"] as? String : nil,
            album:     isActive ? info["Album"]  as? String : nil,
            artwork:   nowPlaying.artwork,          // garde la pochette si déjà chargée
            isPlaying: isPlaying,
            elapsed:   (info["Current Position"] as? Double) ?? 0,
            duration:  (info["Total Time"] as? Double ?? 0) / 1000
        )
        let becameActive = !wasActive && state.isActive
        wasActive = state.isActive
        sourceIsAppleMusic = state.isActive
        nowPlaying = state
        if becameActive { onBecameActive?() }
        updateElapsedTimer()

        // Refresh complet pour récupérer la pochette via MediaRemote
        Task { await refresh() }
    }

    private func refresh() async {
        let state = await source.fetchNowPlayingInfo()
        // Merge : si la distributed notification a déjà le titre, garde-le si MediaRemote est vide
        var merged = state.isActive ? state : nowPlaying
        // Preserve elapsed from distributed-notification timer if MediaRemote doesn't provide it
        if state.isActive && state.elapsed == 0 && nowPlaying.elapsed > 0 && nowPlaying.title == merged.title {
            merged.elapsed = nowPlaying.elapsed
        }
        let becameActive = !wasActive && merged.isActive
        let playStateChanged = merged.isPlaying != nowPlaying.isPlaying
        wasActive = merged.isActive
        nowPlaying = merged
        if becameActive { onBecameActive?() }
        if playStateChanged { updateElapsedTimer() }
    }

    public func send(_ command: MediaCommand) { Task { await source.send(command) } }

    /// Aperçu visuel pendant le glissement (ne pilote pas encore le lecteur).
    public func previewElapsed(_ position: TimeInterval) {
        nowPlaying.elapsed = max(0, min(position, nowPlaying.duration))
    }

    /// Positionne réellement la lecture (à appeler à la fin du glissement).
    public func seek(to position: TimeInterval) {
        let target = max(0, min(position, nowPlaying.duration))
        nowPlaying.elapsed = target
        if sourceIsAppleMusic {
            seekAppleMusic(to: target)   // MediaRemote est bloqué pour Music sur macOS 15
        } else {
            send(.seek(to: target))
        }
    }

    private func seekAppleMusic(to position: TimeInterval) {
        let running = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.apple.Music"
        }
        guard running else { return }
        let script = "tell application \"Music\" to set player position to \(Int(position))"
        Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            try? process.run()
        }
    }

    // MARK: — Elapsed timer

    private func updateElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        guard nowPlaying.isPlaying else { return }
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.nowPlaying.isPlaying else { return }
                self.nowPlaying.elapsed = min(self.nowPlaying.elapsed + 1, self.nowPlaying.duration)
            }
        }
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
    }

    public func makePeekView() -> AnyView { AnyView(MediaPeekView(module: self)) }
    public func makeContentView() -> AnyView { AnyView(MediaContentView(module: self)) }

    deinit {
        mrObserver.map { NotificationCenter.default.removeObserver($0) }
        DistributedNotificationCenter.default().removeObserver(self)
        pollTimer?.invalidate()
        elapsedTimer?.invalidate()
    }
}
