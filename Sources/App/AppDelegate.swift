import AppKit
import Core

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchWindow: NotchWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement = true dans Info.plist pour Xcode ; idem ici pour swift build
        NSApplication.shared.setActivationPolicy(.accessory)
        notchWindow = NotchWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
