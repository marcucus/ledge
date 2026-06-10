import AppKit
import QuartzCore
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

        // sizingOptions = [] empêche SwiftUI de piloter le redimensionnement de la fenêtre
        let hostingView = NSHostingView(rootView: NotchContentView(controller: controller))
        hostingView.sizingOptions = []
        contentView = hostingView

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

    // MARK: — Modules

    public func register(modules: [any NotchModule]) {
        controller.register(modules: modules)
    }

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

    // MARK: — Frame

    private func updateFrame(for state: NotchState, animated: Bool) {
        guard let geometry = currentGeometry else { return }
        controller.notchWidth  = geometry.notchRect.width
        controller.notchHeight = geometry.notchRect.height

        switch state {
        case .expanded:
            // Fond noir pendant l'animation : couvre tout écart entre fenêtre et panneau SwiftUI
            backgroundColor = .black
            let size = CGSize(width: Layout.expandedWidth,
                              height: geometry.notchRect.height + Layout.contentHeight)
            let frame = makeFrame(size: size, geometry: geometry)
            if animated {
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = Layout.openDuration
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    self.animator().setFrame(frame, display: true)
                }, completionHandler: {
                    self.backgroundColor = .clear
                    self.updateTrackingArea()
                })
            } else {
                setFrame(frame, display: true, animate: false)
                backgroundColor = .clear
                updateTrackingArea()
            }
            addGlobalClickMonitor()

        case .collapsed, .peeking:
            backgroundColor = .clear   // annule un éventuel fond noir si l'ouverture était interrompue
            removeGlobalClickMonitor()
            let notchSize = CGSize(width: geometry.notchRect.width,
                                   height: geometry.notchRect.height)
            if animated {
                // Attendre la fin de l'animation SwiftUI de fermeture avant de rétrécir la fenêtre
                let frame = makeFrame(size: notchSize, geometry: geometry)
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(320))
                    guard let self, self.controller.state == .collapsed else { return }
                    self.setFrame(frame, display: true, animate: false)
                    self.updateTrackingArea()
                }
            } else {
                applyFrame(size: notchSize, geometry: geometry)
            }
        }

        orderFrontRegardless()
    }

    private func applyFrame(size: CGSize, geometry: NotchGeometry) {
        setFrame(makeFrame(size: size, geometry: geometry), display: true, animate: false)
        updateTrackingArea()
    }

    private func makeFrame(size: CGSize, geometry: NotchGeometry) -> CGRect {
        CGRect(
            x: geometry.anchorPoint.x - size.width / 2,
            y: geometry.anchorPoint.y - size.height,
            width: size.width,
            height: size.height
        )
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

    // MARK: — Global click monitor

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

// MARK: — Constantes

private enum Layout {
    static let expandedWidth: CGFloat  = 560
    static let contentHeight: CGFloat  = 300
    static let openDuration: TimeInterval  = 0.25
    static let closeDuration: TimeInterval = 0.22
}
