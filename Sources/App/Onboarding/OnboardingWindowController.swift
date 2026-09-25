import AppKit
import Core
import SwiftUI

final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    private let onOpenPermissions: () -> Void

    init(onOpenPermissions: @escaping () -> Void) {
        self.onOpenPermissions = onOpenPermissions
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 470),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        window.delegate = self
        window.title = NSLocalizedString("onboarding.window.title", bundle: localizationBundle, comment: "")
        window.center()
        window.isReleasedWhenClosed = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func show() {
        guard let window else { return }
        window.contentView = NSHostingView(
            rootView: OnboardingView { [weak self] shouldOpenPermissions in
                self?.finish(shouldOpenPermissions: shouldOpenPermissions)
            }
        )
        NSApp.setActivationPolicy(.regular)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func finish(shouldOpenPermissions: Bool) {
        SettingsStore.shared.hasCompletedOnboarding = true
        close()
        if shouldOpenPermissions {
            onOpenPermissions()
        }
    }

    func windowWillClose(_: Notification) {
        SettingsStore.shared.hasCompletedOnboarding = true
        NSApp.setActivationPolicy(.accessory)
    }
}
