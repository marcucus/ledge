import AppKit
import Core

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchWindow: NotchWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement = true dans Info.plist pour Xcode ; idem ici pour swift build
        NSApplication.shared.setActivationPolicy(.accessory)
<<<<<<< Updated upstream
        notchWindow = NotchWindow()
=======
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
        // Auto-sélectionne l'onglet Media quand la lecture démarre
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
        notchWindow = window
        settingsWindowController = settingsWC
>>>>>>> Stashed changes
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
