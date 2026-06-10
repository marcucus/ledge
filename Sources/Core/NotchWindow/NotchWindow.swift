import AppKit
import SwiftUI

public final class NotchWindow: NSPanel {
    let controller = NotchController()

    private var currentGeometry: NotchGeometry?
    private var screenObserver: NSObjectProtocol?
    private var trackingArea: NSTrackingArea?
    private var globalClickMonitor: Any?

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

        contentView = NSHostingView(rootView: PlaceholderView(controller: controller))

        controller.onTransition = { [weak self] state in
            self?.updateFrame(for: state, animated: true)
        }

        observeScreenChanges()
        positionOnNotch()
    }

    deinit {
        screenObserver.map { NotificationCenter.default.removeObserver($0) }
        globalClickMonitor.map { NSEvent.removeMonitor($0) }
    }

    // MARK: — Événements souris

    override public func mouseEntered(with event: NSEvent) { controller.cursorEntered() }
    override public func mouseExited(with event: NSEvent)  { controller.cursorExited() }
    override public func mouseDown(with event: NSEvent)    { controller.panelClicked() }

    // MARK: — Positionnement

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.positionOnNotch() }
    }

    private func positionOnNotch() {
        guard let geometry = NSScreen.withNotch?.notchGeometry() else { return }
        currentGeometry = geometry
        updateFrame(for: controller.state, animated: false)
    }

    // MARK: — Mise à jour du frame (avec ou sans animation)

    private func updateFrame(for state: NotchState, animated: Bool) {
        guard let geometry = currentGeometry else { return }
        let height = Layout.height(for: state)
        let newFrame = CGRect(
            x: geometry.notchRect.minX,
            y: geometry.anchorPoint.y - height,
            width: geometry.notchRect.width,
            height: height
        )

        if animated {
            NSAnimationContext.runAnimationGroup { [self] context in
                context.duration = Motion.duration(for: state)
                context.timingFunction = Motion.curve(for: state)
                animator().setFrame(newFrame, display: true)
            } completionHandler: { [weak self] in
                // Recalcul du tracking area une fois le frame final atteint
                self?.updateTrackingArea()
            }
        } else {
            setFrame(newFrame, display: true, animate: false)
            updateTrackingArea()
        }

        switch state {
        case .expanded:
            addGlobalClickMonitor()
            orderFrontRegardless()
        case .peeking, .collapsed:
            removeGlobalClickMonitor()
            orderFrontRegardless()
        }
    }

    // MARK: — Hot zone

    private func updateTrackingArea() {
        if let old = trackingArea { contentView?.removeTrackingArea(old) }
        guard let contentView else { return }
        let area = NSTrackingArea(
            rect: contentView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        contentView.addTrackingArea(area)
        trackingArea = area
    }

    // MARK: — Global click monitor (dismiss panneau ouvert)

    private func addGlobalClickMonitor() {
        guard globalClickMonitor == nil else { return }
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.controller.dismiss()
        }
    }

    private func removeGlobalClickMonitor() {
        globalClickMonitor.map { NSEvent.removeMonitor($0) }
        globalClickMonitor = nil
    }
}

// MARK: — Dimensions

private enum Layout {
    static func height(for state: NotchState) -> CGFloat {
        switch state {
        case .collapsed: 4      // bande invisible = hot zone
        case .peeking:   50     // aperçu compact
        case .expanded:  300    // panneau complet
        }
    }
}

// MARK: — Animation

private enum Motion {
    // Fermeture rapide (ressenti réactif), ouverture plus douce
    static func duration(for state: NotchState) -> TimeInterval {
        state == .collapsed ? 0.22 : 0.35
    }

    // Courbe spring approximée (bezier cubique) pour l'ouverture ;
    // ease-in simple pour la fermeture (plus naturel qu'un spring inverse)
    static func curve(for state: NotchState) -> CAMediaTimingFunction {
        switch state {
        case .collapsed:
            return CAMediaTimingFunction(name: .easeIn)
        case .peeking, .expanded:
            // Léger dépassement reproduisant l'impulsion spring (~0.15 overshoot)
            return CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1.0)
        }
    }
}

// MARK: — Vue placeholder

// Vue temporaire pour vérifier les transitions visuellement — remplacée en V0.6
private struct PlaceholderView: View {
    var controller: NotchController

    var body: some View {
        UnevenRoundedRectangle(bottomLeadingRadius: 8, bottomTrailingRadius: 8)
            .fill(stateColor.opacity(0.7))
    }

    private var stateColor: Color {
        switch controller.state {
        case .collapsed: .clear
        case .peeking:   .orange
        case .expanded:  .green
        }
    }
}
