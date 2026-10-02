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
    private let settings = SettingsStore.shared
    private var notchWindowCoordinator: NotchWindowCoordinator?
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

        let settingsWC = SettingsWindowController(settings: settings)
        let coordinator = NotchWindowCoordinator(
            settings: settings,
            settingsWindowController: settingsWC
        )
        let onboardingWC = OnboardingWindowController(settings: settings) {
            settingsWC.show(section: .permissions)
        }

        setupStatusItem()
        coordinator.start()
        timerModule = coordinator.assembly.timerModule
        clipboardModule = coordinator.assembly.clipboardModule
        installObservers(for: coordinator)
        notchWindowCoordinator = coordinator
        settingsWindowController = settingsWC
        onboardingWindowController = onboardingWC

        if !settings.hasCompletedOnboarding {
            DispatchQueue.main.async { [weak onboardingWC] in
                onboardingWC?.show()
            }
        }
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
    @MainActor private func installObservers(for coordinator: NotchWindowCoordinator) {
        systemObserver = makeSystemObserver(for: coordinator)
        shortcutManager = makeShortcutManager(for: coordinator)
        frontmostAppObserver = makeFrontmostAppObserver(for: coordinator)
    }

    /// Bascule les modules visibles selon l'app au premier plan (profils par app).
    @MainActor private func makeFrontmostAppObserver(
        for coordinator: NotchWindowCoordinator
    ) -> FrontmostAppObserver {
        let observer = FrontmostAppObserver()
        observer.onActiveAppChange = { [weak coordinator] bundleID in
            coordinator?.updateActiveProfile(bundleID: bundleID)
        }
        coordinator.updateActiveProfile(bundleID: observer.currentBundleID)
        observer.start()
        return observer
    }

    /// Raccourcis globaux, personnalisables depuis Réglages → Raccourcis.
    @MainActor private func makeShortcutManager(for coordinator: NotchWindowCoordinator) -> GlobalShortcutManager {
        let manager = GlobalShortcutManager(settings: settings)

        manager.onOpenClose = { [weak coordinator] in coordinator?.activeWindow?.controller.panelClicked() }

        manager.onPaste = { [weak self] in self?.clipboardModule?.pasteLatest() }

        manager.onNewTimer = { [weak coordinator] in
            let controller = coordinator?.activeWindow?.controller
            controller?.selectModule(id: "timers")
            if controller?.state == .collapsed || controller?.state == .ambient {
                controller?.cursorEntered()
            }
        }

        manager.onOpenMedia = { [weak coordinator] in
            let controller = coordinator?.activeWindow?.controller
            controller?.selectModule(id: "media")
            if controller?.state == .collapsed || controller?.state == .ambient {
                controller?.cursorEntered()
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
            _ = settings.globalShortcutEnabled
            _ = settings.shortcutOpenClose
            _ = settings.shortcutPaste
            _ = settings.shortcutNewTimer
            _ = settings.shortcutOpenMedia
        } onChange: { [weak self, weak manager] in
            Task { @MainActor [weak self, weak manager] in
                guard let manager else { return }
                manager.applySettings()
                self?.observeShortcutSettings(manager)
            }
        }
    }

    /// Branche le HUD volume/luminosité sur la fenêtre encoche.
    @MainActor private func makeSystemObserver(for coordinator: NotchWindowCoordinator) -> SystemObserver {
        let observer = SystemObserver(settings: settings)
        observer.onVolumeChange = { [weak self, weak coordinator] value, isMuted in
            guard let tint = self?.settings.hudAccentColor else { return }
            coordinator?.showHUD(HUDContent(kind: .volume, value: value, isMuted: isMuted, tint: tint))
        }
        observer.onBrightnessChange = { [weak self, weak coordinator] value in
            guard let tint = self?.settings.hudAccentColor else { return }
            coordinator?.showHUD(HUDContent(kind: .brightness, value: value, tint: tint))
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
