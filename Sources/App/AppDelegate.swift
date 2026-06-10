import AppKit
import Core
import MediaModule

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchWindow: NotchWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        let window = NotchWindow()
        window.register(modules: [MediaModule()])
        notchWindow = window
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
