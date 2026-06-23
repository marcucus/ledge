import AppKit
import Core
import Foundation
import SwiftUI

// MARK: — AppLauncherItem

/// A pinned app in the launcher grid.
public struct AppLauncherItem: Identifiable {
    public let id: UUID
    public let bundleURL: URL
    public let name: String

    public init(id: UUID = UUID(), bundleURL: URL, name: String) {
        self.id = id; self.bundleURL = bundleURL; self.name = name
    }
}

// MARK: — SystemModule

@MainActor
@Observable
public final class SystemModule: NotchModule {
    public let id = "system"

    // MARK: — Observed state

    private(set) var battery = BatteryStats.unavailable
    private(set) var cpu = CPUStats.zero
    private(set) var ram = RAMStats.zero
    private(set) var network = NetworkStats.zero

    var toggles: [QuickToggle] = []
    var launcherItems: [AppLauncherItem] = []

    // MARK: — Private sources

    @ObservationIgnored private let batterySource = BatterySource()
    @ObservationIgnored private let pollingSource = PollingSource()
    @ObservationIgnored private let caffeineManager = CaffeineManager()

    @ObservationIgnored private nonisolated(unsafe) var _batterySource: BatterySource
    @ObservationIgnored private nonisolated(unsafe) var _pollingSource: PollingSource

    // MARK: — Init

    public init() {
        _batterySource = batterySource
        _pollingSource = pollingSource
        buildToggles()
        buildDefaultLauncher()
    }

    deinit {
        _batterySource.stop()
        _pollingSource.endPolling()
    }

    // MARK: — NotchModule

    public func start() {
        batterySource.onUpdate = { [weak self] stats in
            Task { @MainActor [weak self] in self?.battery = stats }
        }
        pollingSource.onCPU = { [weak self] stats in Task { @MainActor [weak self] in self?.cpu = stats } }
        pollingSource.onRAM = { [weak self] stats in Task { @MainActor [weak self] in self?.ram = stats } }
        pollingSource.onNetwork = { [weak self] stats in Task { @MainActor [weak self] in self?.network = stats } }
        batterySource.start()
        loadLauncherItems()
        observeLauncherApps()
    }

    public func stop() {
        batterySource.stop()
        pollingSource.endPolling()
    }

    // MARK: — Polling lifecycle (called by the content view)

    /// Call from the content view's `onAppear`.
    func beginPolling() {
        pollingSource.beginPolling()
    }

    /// Call from the content view's `onDisappear`.
    func endPolling() {
        pollingSource.endPolling()
    }

    // MARK: — Launcher

    func launch(item: AppLauncherItem) {
        let cfg = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: item.bundleURL, configuration: cfg)
    }

    // MARK: — Private setup

    private func buildToggles() {
        let caffeine = QuickToggle(
            id: .caffeine,
            icon: "cup.and.saucer",
            labelKey: "system.toggle.caffeine",
            isOn: caffeineManager.isActive
        ) { [weak self] in
            guard let self else { return }
            caffeineManager.toggle()
            refreshCaffeineToggle()
        }

        let muted = MuteManager.isMuted() ?? false
        let muteToggle = QuickToggle(
            id: .mute,
            icon: muted ? "speaker.slash" : "speaker.wave.2",
            labelKey: "system.toggle.mute",
            isOn: muted
        ) { [weak self] in
            guard let self else { return }
            let newState = MuteManager.toggle() ?? false
            refreshMuteToggle(isOn: newState)
        }

        toggles = [caffeine, muteToggle]
    }

    private func refreshCaffeineToggle() {
        guard let idx = toggles.firstIndex(where: { $0.id == .caffeine }) else { return }
        toggles[idx].isOn = caffeineManager.isActive
    }

    private func refreshMuteToggle(isOn: Bool) {
        guard let idx = toggles.firstIndex(where: { $0.id == .mute }) else { return }
        toggles[idx].isOn = isOn
        toggles[idx].icon = isOn ? "speaker.slash" : "speaker.wave.2"
    }

    private func buildDefaultLauncher() {}

    private func loadLauncherItems() {
        launcherItems = SettingsStore.shared.launcherApps.compactMap { path in
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            let url = URL(fileURLWithPath: path)
            let name = url.deletingPathExtension().lastPathComponent
            return AppLauncherItem(bundleURL: url, name: name)
        }
    }

    private func observeLauncherApps() {
        withObservationTracking {
            _ = SettingsStore.shared.launcherApps
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.loadLauncherItems()
                self?.observeLauncherApps()
            }
        }
    }
}

// MARK: — NotchModule protocol conformance

public extension SystemModule {
    var tabIcon: String {
        "cpu"
    }

    var tabLabel: LocalizedStringKey {
        "module.system.label"
    }

    func makePeekView() -> AnyView {
        AnyView(SystemPeekView(module: self))
    }

    func makeContentView() -> AnyView {
        AnyView(SystemContentView(module: self))
    }
}
