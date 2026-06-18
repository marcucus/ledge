import AppKit
import QuartzCore
import SwiftUI

public final class NotchWindow: NSPanel {
    public let controller = NotchController(settings: .shared)

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
        isMovable = false
        hasShadow = false
        hidesOnDeactivate = false

        // sizingOptions = [] empêche SwiftUI de piloter le redimensionnement de la fenêtre
        let hostingView = NSHostingView(rootView: NotchContentView(controller: controller))
        hostingView.sizingOptions = []
        contentView = hostingView

        controller.onTransition = { [weak self] newState in
            guard let self else { return }
            let from = lastState
            lastState = newState
            updateFrame(for: newState, from: from, animated: true)
        }

        observeScreenChanges()
        positionOnNotch()
        startFileDragMonitoring()
        startObservingSettings()
    }

    deinit {
        screenObserver.map { NotificationCenter.default.removeObserver($0) }
        globalClickMonitor.map { NSEvent.removeMonitor($0) }
        globalFileDragMonitor.map { NSEvent.removeMonitor($0) }
        globalFileUpMonitor.map { NSEvent.removeMonitor($0) }
    }

    // MARK: — Observation des réglages

    private func startObservingSettings() {
        withObservationTracking {
            applyCollectionBehavior(for: controller.fullscreenBehavior)
            _ = controller.expandedWidth
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.applyCollectionBehavior(for: self.controller.fullscreenBehavior)
                self.updateFrame(for: self.controller.state, from: self.controller.state, animated: true)
                self.startObservingSettings()
            }
        }
    }

    private func applyCollectionBehavior(for behavior: FullscreenBehavior) {
        switch behavior {
        case .accessible:
            collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        case .hidden:
            collectionBehavior = [.canJoinAllSpaces]
        case .overlay:
            collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        }
    }

    // MARK: — Événements souris

    override public func mouseEntered(with _: NSEvent) {
        controller.cursorEntered()
    }

    override public func mouseExited(with _: NSEvent) {
        controller.cursorExited()
    }

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
        controller.notchWidth = geometry.notchRect.width
        controller.notchHeight = geometry.notchRect.height

        switch state {
        case .expanded: applyExpanded(geometry: geometry, animated: animated)
        case .peeking: applyPeeking(geometry: geometry, animated: animated)
        case .hud: applyHUD(geometry: geometry, animated: animated)
        case .collapsed: applyCollapsed(geometry: geometry, from: from, animated: animated)
        }
        orderFrontRegardless()
    }

    /// Anime (ou pose directement si `animated == false`) la fenêtre vers `frame`,
    /// puis exécute `onComplete`. Factorise la mécanique d'animation des 4 états.
    private func transitionFrame(
        to frame: CGRect,
        duration: TimeInterval,
        animated: Bool,
        onComplete: @escaping () -> Void
    ) {
        guard animated else {
            setFrame(frame, display: true, animate: false)
            onComplete()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().setFrame(frame, display: true)
        } completionHandler: { onComplete() }
    }

    /// Pendant l'animation le fond est noir, puis redevient transparent (la forme SwiftUI prend le relais).
    private func revealClearBackground() {
        backgroundColor = .clear
        updateTrackingArea()
    }

    private func applyExpanded(geometry: NotchGeometry, animated: Bool) {
        backgroundColor = .black
        let size = CGSize(width: controller.expandedWidth, height: Layout.navbarHeight + Layout.contentHeight)
        transitionFrame(
            to: makeFrame(size: size, geometry: geometry),
            duration: Layout.openDuration,
            animated: animated
        ) { [weak self] in
            self?.revealClearBackground()
        }
        addGlobalClickMonitor()
    }

    private func applyPeeking(geometry: NotchGeometry, animated: Bool) {
        backgroundColor = .black
        let size = CGSize(width: controller.expandedWidth, height: Layout.navbarHeight)
        transitionFrame(
            to: makeFrame(size: size, geometry: geometry),
            duration: Layout.peekDuration,
            animated: animated
        ) { [weak self] in
            self?.revealClearBackground()
        }
    }

    private func applyHUD(geometry: NotchGeometry, animated: Bool) {
        // Fenêtre qui entoure l'encoche (plus large des deux côtés), barre fine en dessous.
        backgroundColor = .black
        let size = CGSize(
            width: max(Layout.hudMinWidth, controller.notchWidth + Layout.hudSideMargin),
            height: controller.notchHeight + Layout.hudBottomMargin
        )
        transitionFrame(
            to: makeFrame(size: size, geometry: geometry),
            duration: Layout.peekDuration,
            animated: animated
        ) { [weak self] in
            self?.revealClearBackground()
        }
    }

    private func applyCollapsed(geometry: NotchGeometry, from: NotchState, animated: Bool) {
        backgroundColor = .clear
        removeGlobalClickMonitor()
        let size = CGSize(width: geometry.notchRect.width, height: geometry.notchRect.height)
        guard animated else {
            applyFrame(size: size, geometry: geometry)
            return
        }
        let frame = makeFrame(size: size, geometry: geometry)
        // Depuis peek / hud : rétrécir tout de suite. Depuis expanded : attendre l'animation SwiftUI.
        if from == .peeking || from == .hud {
            transitionFrame(to: frame, duration: Layout.peekDuration, animated: true) { [weak self] in
                self?.updateTrackingArea()
            }
        } else {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(Layout.collapseFromExpandedDelayMs))
                guard let self, controller.state == .collapsed else { return }
                setFrame(frame, display: true, animate: false)
                updateTrackingArea()
            }
        }
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
            x: geometry.anchorPoint.x - controller.expandedWidth / 2,
            y: geometry.notchRect.minY - 120,
            width: controller.expandedWidth,
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
    static let navbarHeight: CGFloat = 44
    static let contentHeight: CGFloat = 180
    static let openDuration: TimeInterval = 0.40
    static let closeDuration: TimeInterval = 0.34
    static let peekDuration: TimeInterval = 0.20
    // HUD : la fenêtre déborde de chaque côté de l'encoche, barre fine en dessous.
    static let hudMinWidth: CGFloat = 280
    static let hudSideMargin: CGFloat = 170
    static let hudBottomMargin: CGFloat = 34
    /// Attendre la fin de l'animation SwiftUI avant de rétrécir la fenêtre depuis l'état ouvert.
    static let collapseFromExpandedDelayMs = 380
}
