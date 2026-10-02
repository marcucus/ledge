import AppKit
import Core
import DropZoneModule
import MediaModule
import SystemModule
import TimerModule

@MainActor
final class NotchWindowCoordinator {
    private let settings: SettingsStore
    private let settingsWindowController: SettingsWindowController
    let assembly: AppModuleAssembly
    private(set) var windows: [NotchWindow] = []
    private var screenObserver: NSObjectProtocol?
    private var activeBundleIdentifier: String?

    init(settings: SettingsStore, settingsWindowController: SettingsWindowController) {
        self.settings = settings
        self.settingsWindowController = settingsWindowController
        assembly = AppModuleAssembly(settings: settings)
        configureModuleContributions()
    }

    deinit {
        screenObserver.map { NotificationCenter.default.removeObserver($0) }
    }

    func start() {
        assembly.systemModule.start()
        rebuildWindows()
        observeTargetSettings()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.rebuildWindows() }
        }
    }

    var activeWindow: NotchWindow? {
        let mouseLocation = NSEvent.mouseLocation
        return windows.first { window in
            NSScreen.screen(identifier: window.fixedTargetScreenIdentifier ?? "")?.frame
                .contains(mouseLocation) == true
        } ?? windows.first
    }

    func forEachController(_ action: (NotchController) -> Void) {
        windows.forEach { action($0.controller) }
    }

    func showHUD(_ content: HUDContent) {
        forEachController { $0.showHUD(content) }
    }

    func updateActiveProfile(bundleID: String?) {
        activeBundleIdentifier = bundleID
        forEachController { $0.updateActiveProfile(bundleID: bundleID) }
    }

    private func configureModuleContributions() {
        assembly.dropZoneModule.onAmbientUpdate = { [weak self] content in
            self?.forEachController { $0.setAmbient(content, sourceID: "dropzone", priority: 1) }
        }
        assembly.mediaModule.onBecameActive = { [weak self] in
            self?.forEachController { $0.selectModule(id: "media") }
        }
        assembly.mediaModule.onAmbientUpdate = { [weak self] content in
            self?.forEachController { $0.setAmbient(content, sourceID: "media", priority: 3) }
        }
        assembly.timerModule.onAmbientUpdate = { [weak self] content in
            self?.forEachController { $0.setAmbient(content, sourceID: "timers", priority: 2) }
        }
        assembly.timerModule.onFinished = { [weak self] in
            guard let self, settings.timerFinishedPeekEnabled else { return }
            forEachController {
                $0.showPeek(selecting: "timers", duration: self.settings.timerFinishedPeekDuration)
            }
        }
    }

    private func observeTargetSettings() {
        withObservationTracking {
            _ = settings.displayTargetMode
            _ = settings.selectedScreenIdentifiers
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.rebuildWindows()
                self?.observeTargetSettings()
            }
        }
    }

    private func rebuildWindows() {
        let descriptors = NSScreen.availableDescriptors
        let targets = DisplayTargetSelection.resolvedIdentifiers(
            mode: settings.displayTargetMode,
            selectedIdentifiers: settings.selectedScreenIdentifiers,
            availableIdentifiers: descriptors.map(\.id)
        )
        let existing = Dictionary(uniqueKeysWithValues: windows.map { (key(for: $0), $0) })
        var nextWindows: [NotchWindow] = []

        for target in targets {
            let targetKey = key(for: target)
            if let window = existing[targetKey] {
                nextWindows.append(window)
            } else {
                nextWindows.append(makeWindow(targetScreenIdentifier: target))
            }
        }

        let retained = Set(nextWindows.map(ObjectIdentifier.init))
        windows.filter { !retained.contains(ObjectIdentifier($0)) }.forEach { $0.orderOut(nil) }
        windows = nextWindows
    }

    private func makeWindow(targetScreenIdentifier: String?) -> NotchWindow {
        let window = NotchWindow(settings: settings, targetScreenIdentifier: targetScreenIdentifier)
        window.controller.openSettings = { [weak settingsWindowController] in
            settingsWindowController?.show()
        }
        window.controller.statusModule = assembly.systemModule
        window.controller.onDragHoverChange = { [weak dropZoneModule = assembly.dropZoneModule] active in
            dropZoneModule?.isDragActive = active
        }
        window.register(modules: assembly.navigationModules)
        window.controller.updateActiveProfile(bundleID: activeBundleIdentifier)
        return window
    }

    private func key(for window: NotchWindow) -> String {
        key(for: window.fixedTargetScreenIdentifier)
    }

    private func key(for identifier: String?) -> String {
        identifier ?? "__automatic__"
    }
}
