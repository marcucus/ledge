import AppKit
import CalendarModule
import ClipboardModule
import Core
import DropZoneModule
import MediaModule
import NotesModule
import ShortcutsModule
import Sparkle
import SystemModule
import TimerModule

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchWindow: NotchWindow?
    private var settingsWindowController: SettingsWindowController?
    private var onboardingWindowController: OnboardingWindowController?
    private var systemObserver: SystemObserver?
    private var shortcutManager: GlobalShortcutManager?
    private(set) var updaterController: SPUStandardUpdaterController?
    private var statusItem: NSStatusItem?
    private var timerModule: TimerModule?
    private var clipboardModule: ClipboardModule?
    private var frontmostAppObserver: FrontmostAppObserver?

    func applicationDidFinishLaunching(_: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        setAppIcon()
        setupUpdater()

        let window = NotchWindow()
        let settingsWC = SettingsWindowController()
        window.controller.openSettings = { settingsWC.show() }
        let onboardingWC = OnboardingWindowController {
            settingsWC.show(section: .permissions)
        }

        setupStatusItem()
        buildAndRegisterModules(in: window)
        installObservers(for: window)
        notchWindow = window
        settingsWindowController = settingsWC
        onboardingWindowController = onboardingWC

        if !SettingsStore.shared.hasCompletedOnboarding {
            DispatchQueue.main.async { [weak onboardingWC] in
                onboardingWC?.show()
            }
        }
    }

    /// Instancie les modules, câble leurs contributions ambient, et les enregistre dans la fenêtre.
    @MainActor private func buildAndRegisterModules(in window: NotchWindow) {
        // Module Système masqué pour le moment : conservé comme source de statut (batterie dans
        // la NavBar) et démarré manuellement, mais retiré des onglets (absent de register()).
        let systemModule = SystemModule()
        window.controller.statusModule = systemModule
        systemModule.start()

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
        self.timerModule = timerModule

        let clipboardModule = ClipboardModule()
        self.clipboardModule = clipboardModule

        window.register(modules: [
            mediaModule, timerModule, dropZoneModule, clipboardModule,
            ShortcutsModule(), CalendarModule(), NotesModule(),
        ])
    }

    /// Sparkle nécessite un vrai `.app` bundle — ne pas démarrer depuis `swift run`.
    private func setupUpdater() {
        guard Bundle.main.bundlePath.hasSuffix(".app"),
              Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") is String
        else { return }
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    /// Branche les observateurs système (HUD, raccourcis globaux, app active).
    @MainActor private func installObservers(for window: NotchWindow) {
        systemObserver = makeSystemObserver(for: window)
        shortcutManager = makeShortcutManager(for: window)
        frontmostAppObserver = makeFrontmostAppObserver(for: window)
    }

    /// Bascule les modules visibles selon l'app au premier plan (profils par app).
    @MainActor private func makeFrontmostAppObserver(for window: NotchWindow) -> FrontmostAppObserver {
        let observer = FrontmostAppObserver()
        observer.onActiveAppChange = { [weak window] bundleID in
            window?.controller.updateActiveProfile(bundleID: bundleID)
        }
        window.controller.updateActiveProfile(bundleID: observer.currentBundleID)
        observer.start()
        return observer
    }

    /// Raccourcis globaux, personnalisables depuis Réglages → Raccourcis.
    @MainActor private func makeShortcutManager(for window: NotchWindow) -> GlobalShortcutManager {
        let manager = GlobalShortcutManager(settings: .shared)

        manager.onOpenClose = { [weak window] in window?.controller.panelClicked() }

        manager.onPaste = { [weak self] in self?.clipboardModule?.pasteLatest() }

        manager.onNewTimer = { [weak window] in
            window?.controller.selectModule(id: "timers")
            if window?.controller.state == .collapsed || window?.controller.state == .ambient {
                window?.controller.cursorEntered()
            }
        }

        manager.onOpenMedia = { [weak window] in
            window?.controller.selectModule(id: "media")
            if window?.controller.state == .collapsed || window?.controller.state == .ambient {
                window?.controller.cursorEntered()
            }
        }

        applyShortcutSetting(manager)
        return manager
    }

    @MainActor
    private func applyShortcutSetting(_ manager: GlobalShortcutManager) {
        manager.applySettings()
        observeShortcutSettings(manager)
    }

    /// Réagit aux changements du toggle global et des 4 combinaisons (Réglages → Raccourcis).
    @MainActor
    private func observeShortcutSettings(_ manager: GlobalShortcutManager) {
        withObservationTracking {
            _ = SettingsStore.shared.globalShortcutEnabled
            _ = SettingsStore.shared.shortcutOpenClose
            _ = SettingsStore.shared.shortcutPaste
            _ = SettingsStore.shared.shortcutNewTimer
            _ = SettingsStore.shared.shortcutOpenMedia
        } onChange: { [weak self, weak manager] in
            Task { @MainActor [weak self, weak manager] in
                guard let manager else { return }
                manager.applySettings()
                self?.observeShortcutSettings(manager)
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
        menu.addItem(makeMenuItem(titleKey: "action.settings", action: #selector(openSettings), key: ","))
        menu.addItem(makeMenuItem(titleKey: "onboarding.menu", action: #selector(openOnboarding)))
        menu.addItem(.separator())
        menu.addItem(makeMenuItem(titleKey: "settings.about.checkUpdates", action: #selector(checkForUpdatesAction)))
        menu.addItem(.separator())
        menu.addItem(makeMenuItem(titleKey: "action.quit", action: #selector(NSApplication.terminate(_:)), key: "q"))
        item.menu = menu
        statusItem = item
    }

    private func makeMenuItem(titleKey: String, action: Selector, key: String = "") -> NSMenuItem {
        NSMenuItem(
            title: NSLocalizedString(titleKey, bundle: localizationBundle, comment: ""),
            action: action,
            keyEquivalent: key
        )
    }

    @objc private func openSettings() {
        settingsWindowController?.show()
    }

    @objc private func openOnboarding() {
        onboardingWindowController?.show()
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
