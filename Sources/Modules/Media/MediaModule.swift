import AppKit
import SwiftUI
import Core

@MainActor @Observable public final class MediaModule: NotchModule {
    public let id = "media"
    public let tabIcon = "music.note"
    public let tabLabel: LocalizedStringKey = "module.media.label"

    private(set) var nowPlaying: MediaState = .empty
    private let source: any MediaSource
    @ObservationIgnored nonisolated(unsafe) private var notificationObserver: NSObjectProtocol?

    public init() {
        source = MediaRemoteSource()
    }

    public func start() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { [weak self] in await self?.refresh() }
        }
        Task { await refresh() }
    }

    private func refresh() async {
        nowPlaying = await source.fetchNowPlayingInfo()
    }

    public func send(_ command: MediaCommand) {
        Task { await source.send(command) }
    }

    public func stop() {
        notificationObserver.map { NotificationCenter.default.removeObserver($0) }
        notificationObserver = nil
    }

    public func makePeekView() -> AnyView { AnyView(MediaPeekView(module: self)) }
    public func makeContentView() -> AnyView { AnyView(MediaContentView(module: self)) }

    deinit {
        notificationObserver.map { NotificationCenter.default.removeObserver($0) }
    }
}
