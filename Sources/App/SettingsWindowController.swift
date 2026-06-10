import AppKit
import SwiftUI
import Core

final class SettingsWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = NSLocalizedString("settings.window.title", comment: "")
        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        self.init(window: window)
        let hostingView = NSHostingView(
            rootView: SettingsRootView(store: SettingsStore.shared)
        )
        window.contentView = hostingView
    }

    func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
