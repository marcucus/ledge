import AppKit
import SwiftUI
import Core

@MainActor @Observable public final class MediaModule: NotchModule {
    public let id = "media"
    public let tabIcon = "music.note"
    public let tabLabel: LocalizedStringKey = "module.media.label"

    public private(set) var nowPlaying: MediaState = .empty

    /// Appelé quand la lecture démarre alors qu'elle était inactive.
    public var onBecameActive: (() -> Void)?

    private let source: any MediaSource
    @ObservationIgnored nonisolated(unsafe) private var notificationObserver: NSObjectProtocol?
    @ObservationIgnored nonisolated(unsafe) private var pollTimer: Timer?
    @ObservationIgnored private var wasActive = false

    public init() {
        source = MediaRemoteSource()
    }

    public func start() {
        // Notification système quand le titre/état change
        notificationObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { [weak self] in await self?.refresh() }
        }

        // Polling de secours toutes les 3 s (les notifications MediaRemote sont parfois tardives)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { [weak self] in await self?.refresh() }
        }

        Task { await refresh() }
    }

    private func refresh() async {
        let state = await source.fetchNowPlayingInfo()
        let becameActive = !wasActive && state.isActive
        wasActive = state.isActive
        nowPlaying = state
        if becameActive { onBecameActive?() }
    }

    public func send(_ command: MediaCommand) {
        Task { await source.send(command) }
    }

    public func stop() {
        notificationObserver.map { NotificationCenter.default.removeObserver($0) }
        notificationObserver = nil
        pollTimer?.invalidate()
        pollTimer = nil
    }

    public func makePeekView() -> AnyView { AnyView(MediaPeekView(module: self)) }
    public func makeContentView() -> AnyView { AnyView(MediaContentView(module: self)) }

    deinit {
        notificationObserver.map { NotificationCenter.default.removeObserver($0) }
        pollTimer?.invalidate()
    }
}
