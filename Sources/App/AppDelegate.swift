import AppKit
import ClipboardModule
import Core
import DropZoneModule
import MediaModule
import SystemModule
import TimerModule

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchWindow: NotchWindow?
    private var settingsWindowController: SettingsWindowController?
    private var systemObserver: SystemObserver?

    func applicationDidFinishLaunching(_: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        let window = NotchWindow()
        let settingsWC = SettingsWindowController()
        window.controller.openSettings = { settingsWC.show() }

        let systemModule = SystemModule()
        window.controller.statusModule = systemModule

        let dropZoneModule = DropZoneModule()
        window.controller.onDragHoverChange = { [weak dropZoneModule] active in
            dropZoneModule?.isDragActive = active
        }

        let mediaModule = MediaModule()
        mediaModule.onBecameActive = { [weak window] in
            window?.controller.selectModule(id: "media")
        }

        window.register(modules: [
            mediaModule,
            TimerModule(),
            dropZoneModule,
            ClipboardModule(),
            systemModule,
        ])

        systemObserver = makeSystemObserver(for: window)
        notchWindow = window
        settingsWindowController = settingsWC
    }

    /// Branche le HUD volume/luminosité sur la fenêtre encoche.
    @MainActor private func makeSystemObserver(for window: NotchWindow) -> SystemObserver {
        let observer = SystemObserver(settings: .shared)
        observer.onVolumeChange = { [weak window] value, isMuted in
            window?.controller.showHUD(HUDContent(kind: .volume, value: value, isMuted: isMuted))
        }
        observer.onBrightnessChange = { [weak window] value in
            window?.controller.showHUD(HUDContent(kind: .brightness, value: value))
        }
        observer.start()
        return observer
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }
}
