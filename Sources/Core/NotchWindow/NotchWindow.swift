import AppKit
import SwiftUI

public final class NotchWindow: NSPanel {
    private var screenObserver: NSObjectProtocol?

    public init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        level = .init(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovable = false
        hasShadow = false
        hidesOnDeactivate = false

        contentView = NSHostingView(rootView: PlaceholderView())

        observeScreenChanges()
        positionOnNotch()
    }

    deinit {
        screenObserver.map { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: — Positionnement

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.positionOnNotch()
        }
    }

    private func positionOnNotch() {
        guard let geometry = NSScreen.withNotch?.notchGeometry() else { return }
        let frame = CGRect(
            x: geometry.notchRect.minX,
            y: geometry.anchorPoint.y - Layout.placeholderHeight,
            width: geometry.notchRect.width,
            height: Layout.placeholderHeight
        )
        setFrame(frame, display: true, animate: false)
        orderFrontRegardless()
    }
}

// MARK: — Constantes

private enum Layout {
    // Hauteur de l'indicateur visible en V0.3 — remplacé par la hauteur dynamique en V0.4
    static let placeholderHeight: CGFloat = 12
}

// MARK: — Vue placeholder

// Vue temporaire pour vérifier le positionnement — remplacée en V0.6
private struct PlaceholderView: View {
    var body: some View {
        UnevenRoundedRectangle(bottomLeadingRadius: 8, bottomTrailingRadius: 8)
            .fill(.blue.opacity(0.7))
    }
}
