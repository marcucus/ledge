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
        // Le bundle n'a pas d'icône Dock par défaut, et l'icône posée au lancement (mode accessoire)
        // ne « prend » pas toujours au passage en .regular → on la repose explicitement ici.
        applyDockIcon()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func applyDockIcon() {
        guard let url = Bundle.module.url(forResource: "ledgelogo", withExtension: "png"),
              let logo = NSImage(contentsOf: url)
        else { return }
        NSApp.applicationIconImage = Self.macOSIcon(from: logo)
    }

    /// Recompose le logo au gabarit d'icône macOS (grille Big Sur) : corps de 824 px centré dans
    /// une tuile de 1024, coins arrondis ~22 %, logo en aspect-fill clippé par la tuile — pour un
    /// rendu identique aux icônes natives du Dock (taille et bords arrondis).
    private static func macOSIcon(from logo: NSImage) -> NSImage {
        let side: CGFloat = 1024
        let margin: CGFloat = 100
        let body = NSRect(x: margin, y: margin, width: side - margin * 2, height: side - margin * 2)
        let radius = body.width * 0.2237

        let canvas = NSImage(size: NSSize(width: side, height: side))
        canvas.lockFocus()
        NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius).addClip()

        let scale = max(body.width / logo.size.width, body.height / logo.size.height)
        let drawSize = NSSize(width: logo.size.width * scale, height: logo.size.height * scale)
        let origin = NSPoint(x: body.midX - drawSize.width / 2, y: body.midY - drawSize.height / 2)
        logo.draw(
            in: NSRect(origin: origin, size: drawSize),
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0
        )
        canvas.unlockFocus()
        return canvas
    }

    func windowWillClose(_: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
