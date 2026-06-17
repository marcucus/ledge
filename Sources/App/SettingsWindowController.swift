import AppKit
import Core
import SwiftUI

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = NSLocalizedString("settings.window.title", bundle: localizationBundle, comment: "")
        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        self.init(window: window)
        window.delegate = self
        let hostingView = NSHostingView(
            rootView: SettingsRootView(store: SettingsStore.shared)
        )
        window.contentView = hostingView
    }

    func show() {
        NSApp.setActivationPolicy(.regular)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
