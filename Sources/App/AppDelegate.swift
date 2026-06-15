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

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        notchWindow = window
        settingsWindowController = settingsWC
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
