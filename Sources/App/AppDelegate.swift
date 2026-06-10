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
        window.register(modules: [
            MediaModule(),
            TimerModule(),
            DropZoneModule(),
            ClipboardModule(),
            SystemModule(),
        ])
        notchWindow = window
        settingsWindowController = settingsWC
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
