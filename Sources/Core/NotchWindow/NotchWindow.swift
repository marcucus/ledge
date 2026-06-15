import AppKit
import QuartzCore
import SwiftUI

public final class NotchWindow: NSPanel {
    public let controller = NotchController()

    private var currentGeometry: NotchGeometry?
    private var screenObserver: NSObjectProtocol?
    private var trackingArea: NSTrackingArea?
    private var globalClickMonitor: Any?
    private var globalFileDragMonitor: Any?
    private var globalFileUpMonitor: Any?
    private var lastState: NotchState = .collapsed
    private var isTrackingFileDrag = false

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

        controller.onTransition = { [weak self] newState in
            guard let self else { return }
            let from = self.lastState
            self.lastState = newState
            self.updateFrame(for: newState, from: from, animated: true)
        }

        observeScreenChanges()
        positionOnNotch()
        startFileDragMonitoring()
    }

    deinit {
        screenObserver.map { NotificationCenter.default.removeObserver($0) }
        globalClickMonitor.map { NSEvent.removeMonitor($0) }
        globalFileDragMonitor.map { NSEvent.removeMonitor($0) }
        globalFileUpMonitor.map { NSEvent.removeMonitor($0) }
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
        updateFrame(for: controller.state, from: .collapsed, animated: false)
    }

    // MARK: — Frame

    private func updateFrame(for state: NotchState, from: NotchState, animated: Bool) {
        guard let geometry = currentGeometry else { return }
        controller.notchWidth  = geometry.notchRect.width
        controller.notchHeight = geometry.notchRect.height

        switch state {
        case .expanded:
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

        case .peeking:
            // Même hauteur que l'encoche, juste plus large
            backgroundColor = .black
            let size = CGSize(width: Layout.expandedWidth,
                              height: geometry.notchRect.height)
            let frame = makeFrame(size: size, geometry: geometry)
            if animated {
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = Layout.peekDuration
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

        case .collapsed:
            backgroundColor = .clear
            removeGlobalClickMonitor()
            let notchSize = CGSize(width: geometry.notchRect.width,
                                   height: geometry.notchRect.height)
            if animated {
                let frame = makeFrame(size: notchSize, geometry: geometry)
                // Depuis peek : rétrécir en largeur immédiatement (hauteur inchangée)
                // Depuis expanded : attendre la fin de l'animation SwiftUI
                if from == .peeking {
                    NSAnimationContext.runAnimationGroup { ctx in
                        ctx.duration = Layout.peekDuration
                        ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                        self.animator().setFrame(frame, display: true)
                    } completionHandler: {
                        self.updateTrackingArea()
                    }
                } else {
                    Task { @MainActor [weak self] in
                        try? await Task.sleep(for: .milliseconds(380))
                        guard let self, self.controller.state == .collapsed else { return }
                        self.setFrame(frame, display: true, animate: false)
                        self.updateTrackingArea()
                    }
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

    // MARK: — File drag monitoring

    private func startFileDragMonitoring() {
        globalFileDragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] _ in
            Task { @MainActor [weak self] in self?.handleGlobalFileDrag() }
        }
        globalFileUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            Task { @MainActor [weak self] in self?.handleFileDragEnd() }
        }
    }

    private func handleGlobalFileDrag() {
        // Vérifie si le drag contient des fichiers
        let types = NSPasteboard(name: .drag).types ?? []
        let hasFiles = types.contains(where: {
            $0.rawValue == "public.file-url" || $0.rawValue == "NSFilenamesPboardType"
        })
        guard hasFiles else {
            if isTrackingFileDrag { endFileDragTracking() }
            return
        }

        // Zone de proximité : 120 px sous l'encoche, pleine largeur expanded
        guard let geometry = currentGeometry else { return }
        let mouse = NSEvent.mouseLocation
        let zone = CGRect(
            x: geometry.anchorPoint.x - Layout.expandedWidth / 2,
            y: geometry.notchRect.minY - 120,
            width: Layout.expandedWidth,
            height: 120 + geometry.notchRect.height
        )

        if zone.contains(mouse) {
            if !isTrackingFileDrag {
                isTrackingFileDrag = true
                let dropzoneID = controller.modules.first(where: { $0.id == "dropzone" })?.id ?? "dropzone"
                controller.dragApproachNotch(preferredModuleID: dropzoneID)
            }
        } else if isTrackingFileDrag {
            endFileDragTracking()
        }
    }

    private func handleFileDragEnd() {
        if isTrackingFileDrag { endFileDragTracking() }
    }

    private func endFileDragTracking() {
        isTrackingFileDrag = false
        controller.dragLeftProximity()
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
    static let expandedWidth: CGFloat       = 744   // 720 contenu + 12 px d'oreille de chaque côté
    static let navbarHeight: CGFloat        = 44
    static let contentHeight: CGFloat       = 180
    static let openDuration: TimeInterval   = 0.40
    static let closeDuration: TimeInterval  = 0.34
    static let peekDuration: TimeInterval   = 0.20
}
