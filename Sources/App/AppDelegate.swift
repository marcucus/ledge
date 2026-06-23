import AppKit
import ClipboardModule
import Core
import DropZoneModule
import MediaModule
import Sparkle
import SystemModule
import TimerModule

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchWindow: NotchWindow?
    private var settingsWindowController: SettingsWindowController?
    private var systemObserver: SystemObserver?
    private var shortcutManager: GlobalShortcutManager?
    private(set) var updaterController: SPUStandardUpdaterController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        setAppIcon()
        // Sparkle nécessite un vrai .app bundle — ne pas démarrer depuis swift run
        if Bundle.main.bundlePath.hasSuffix(".app") {
            updaterController = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        }

        let window = NotchWindow()
        let settingsWC = SettingsWindowController()
        window.controller.openSettings = { settingsWC.show() }

        setupStatusItem()

        let systemModule = SystemModule()
        window.controller.statusModule = systemModule

        let dropZoneModule = DropZoneModule()
        dropZoneModule.onAmbientUpdate = { [weak window] content in
            window?.controller.setAmbient(content, sourceID: "dropzone", priority: 1)
        }
        window.controller.onDragHoverChange = { [weak dropZoneModule] active in
            dropZoneModule?.isDragActive = active
        }

        let mediaModule = MediaModule()
        mediaModule.onBecameActive = { [weak window] in
            window?.controller.selectModule(id: "media")
        }
        mediaModule.onAmbientUpdate = { [weak window] content in
            window?.controller.setAmbient(content, sourceID: "media", priority: 3)
        }

        let timerModule = TimerModule()
        timerModule.onAmbientUpdate = { [weak window] content in
            window?.controller.setAmbient(content, sourceID: "timers", priority: 2)
        }

        window.register(modules: [
            mediaModule,
            timerModule,
            dropZoneModule,
            ClipboardModule(),
            systemModule,
        ])

        systemObserver = makeSystemObserver(for: window)
        shortcutManager = makeShortcutManager(for: window)
        notchWindow = window
        settingsWindowController = settingsWC
    }

    /// Raccourci global ⌥ Space pour ouvrir/fermer le panneau.
    @MainActor private func makeShortcutManager(for window: NotchWindow) -> GlobalShortcutManager {
        let manager = GlobalShortcutManager()
        manager.onActivated = { [weak window] in window?.controller.panelClicked() }
        applyShortcutSetting(manager)
        return manager
    }

    @MainActor
    private func applyShortcutSetting(_ manager: GlobalShortcutManager) {
        if SettingsStore.shared.globalShortcutEnabled {
            manager.enable()
        } else {
            manager.disable()
        }
        withObservationTracking {
            _ = SettingsStore.shared.globalShortcutEnabled
        } onChange: { [weak manager] in
            Task { @MainActor [weak manager] in
                guard let manager else { return }
                if SettingsStore.shared.globalShortcutEnabled {
                    manager.enable()
                } else {
                    manager.disable()
                }
            }
        }
    }

    /// Branche le HUD volume/luminosité sur la fenêtre encoche.
    @MainActor private func makeSystemObserver(for window: NotchWindow) -> SystemObserver {
        let observer = SystemObserver(settings: .shared)
        observer.onVolumeChange = { [weak window] value, isMuted in
            let tint = SettingsStore.shared.hudAccentColor
            window?.controller.showHUD(HUDContent(kind: .volume, value: value, isMuted: isMuted, tint: tint))
        }
        observer.onBrightnessChange = { [weak window] value in
            let tint = SettingsStore.shared.hudAccentColor
            window?.controller.showHUD(HUDContent(kind: .brightness, value: value, tint: tint))
        }
        observer.start()
        return observer
    }

    // MARK: — Icône app (Dock + About)

    private func setAppIcon() {
        if let url = Bundle.module.url(forResource: "ledgelogo", withExtension: "png"),
           let icon = NSImage(contentsOf: url) {
            NSApplication.shared.applicationIconImage = icon
        }
    }

    // MARK: — Menu bar

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "Ledge")
        item.button?.image?.isTemplate = true

        let menu = NSMenu()

        let settingsItem = NSMenuItem(
            title: NSLocalizedString("action.settings", bundle: localizationBundle, comment: ""),
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let updateItem = NSMenuItem(
            title: NSLocalizedString("settings.about.checkUpdates", bundle: localizationBundle, comment: ""),
            action: #selector(checkForUpdatesAction),
            keyEquivalent: ""
        )
        menu.addItem(updateItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: NSLocalizedString("action.quit", bundle: localizationBundle, comment: ""),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    @objc private func openSettings() {
        settingsWindowController?.show()
    }

    @objc private func checkForUpdatesAction() {
        checkForUpdates()
    }

    func checkForUpdates() {
        updaterController?.updater.checkForUpdates()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }
}
