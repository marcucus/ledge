import AppKit
import QuartzCore
import SwiftUI

// La fenêtre centralise volontairement le cycle de vie AppKit et ses transitions géométriques.
// swiftlint:disable:next type_body_length
public final class NotchWindow: NSPanel {
    public let controller = NotchController(settings: .shared)

    private var currentGeometry: NotchGeometry?
    private var screenObserver: NSObjectProtocol?
    private var trackingArea: NSTrackingArea?
    private let dismissMonitor = NotchDismissMonitor()
    private let fileDragMonitor = NotchFileDragMonitor()
    private var lastState: NotchState = .collapsed
    private var isTargetScreenFullscreen = false
    private lazy var fullscreenMonitor = FullscreenMonitor { [weak self] isFullscreen in
        self?.handleFullscreenChange(isFullscreen)
    }

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
        fullscreenMonitor.start()
        startFileDragMonitoring()
        startObservingSettings()
    }

    deinit {
        screenObserver.map { NotificationCenter.default.removeObserver($0) }
        dismissMonitor.stop()
        fileDragMonitor.stop()
    }

    // MARK: — Observation des réglages

    private func startObservingSettings() {
        withObservationTracking {
            applyCollectionBehavior(for: controller.fullscreenBehavior)
            _ = controller.expandedWidth
            _ = controller.expandedContentHeight
            _ = controller.targetScreenIdentifier
            _ = controller.targetScreenName
            _ = controller.hotZoneHorizontalInset
            _ = controller.hotZoneBottomInset
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.applyCollectionBehavior(for: self.controller.fullscreenBehavior)
                self.controller.updateFullscreenStatus(isActive: self.isTargetScreenFullscreen)
                self.positionOnNotch()
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
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.positionOnNotch()
            }
        }
    }

    private func positionOnNotch() {
        let screen = resolvedTargetScreen()
        fullscreenMonitor.updateTargetScreen(screen)
        guard let geometry = screen?.notchGeometry() ?? screen.map({ scr in
            // Écran sans encoche : ancre une encoche simulée au centre du bord supérieur.
            let bounds = scr.frame
            let size = NotchGeometry.fallbackSize
            let rect = CGRect(x: bounds.midX - size.width / 2, y: bounds.maxY - size.height,
                              width: size.width, height: size.height)
            return NotchGeometry(notchRect: rect, screenFrame: bounds)
        }) else { return }
        currentGeometry = geometry
        updateFrame(for: controller.state, from: .collapsed, animated: false)
    }

    /// Honore la cible explicite tant qu'elle est connectée. Si elle disparaît, Ledge revient
    /// temporairement sur l'écran intégré sans effacer le choix, puis la retrouve à la reconnexion.
    private func resolvedTargetScreen() -> NSScreen? {
        let identifier = controller.targetScreenIdentifier
        if !identifier.isEmpty {
            return NSScreen.screen(identifier: identifier) ?? NSScreen.withNotch ?? NSScreen.main
        }

        let legacyName = controller.targetScreenName
        if !legacyName.isEmpty {
            return NSScreen.screen(named: legacyName) ?? NSScreen.withNotch ?? NSScreen.main
        }
        return NSScreen.withNotch ?? NSScreen.main
    }

    // MARK: — Frame

    private func updateFrame(for state: NotchState, from: NotchState, animated: Bool) {
        guard let geometry = currentGeometry else { return }
        controller.notchWidth = geometry.notchRect.width
        controller.notchHeight = geometry.notchRect.height

        switch state {
        case .expanded: applyExpanded(geometry: geometry, from: from, animated: animated)
        case .peeking: applyPeeking(geometry: geometry, animated: animated)
        case .hud: applyHUD(geometry: geometry, animated: animated)
        case .ambient: applyAmbient(geometry: geometry, animated: animated)
        case .collapsed: applyCollapsed(geometry: geometry, from: from, animated: animated)
        }
        applyFullscreenVisibility()
    }

    /// Anime (ou pose directement si `animated == false`) la fenêtre vers `frame`,
    /// puis exécute `onComplete`. Factorise la mécanique d'animation des 4 états.
    private func transitionFrame(
        to frame: CGRect,
        duration: TimeInterval,
        animated: Bool,
        onComplete: @escaping () -> Void
    ) {
        let shouldAnimate = animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        guard shouldAnimate else {
            setFrame(frame, display: true, animate: false)
            onComplete()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = NotchWindowLayout.expansionTiming
            self.animator().setFrame(frame, display: true)
        } completionHandler: { onComplete() }
    }

    /// Pendant l'animation le fond est noir, puis redevient transparent (la forme SwiftUI prend le relais).
    private func revealClearBackground() {
        backgroundColor = .clear
        updateTrackingArea()
        // Si le curseur a quitté la fenêtre pendant l'animation d'ouverture (window.frame était déjà
        // à la taille expanded dès le début → mouseExited filtré), on déclenche la fermeture ici.
        let mouse = NSEvent.mouseLocation
        let containsMouse = mouse.x >= frame.minX && mouse.x <= frame.maxX && 
                            mouse.y >= frame.minY && mouse.y <= frame.maxY
        if !containsMouse {
            controller.cursorExited()
        }
    }

    private func applyExpanded(geometry: NotchGeometry, from _: NotchState, animated: Bool) {
        let size = CGSize(
            width: controller.expandedWidth,
            height: controller.navigationHeight + controller.expandedContentHeight
        )
        transitionFrame(
            to: makeFrame(size: size, geometry: geometry),
            duration: NotchWindowLayout.openDuration * controller.animationScale,
            animated: animated
        ) { [weak self] in
            self?.controller.expansionDidFinish()
            self?.revealClearBackground()
        }
        addDismissMonitors()
    }

    private func applyPeeking(geometry: NotchGeometry, animated: Bool) {
        removeDismissMonitors()
        let size = CGSize(width: controller.expandedWidth, height: controller.navigationHeight)
        transitionFrame(
            to: makeFrame(size: size, geometry: geometry),
            duration: NotchWindowLayout.peekDuration * controller.animationScale,
            animated: animated
        ) { [weak self] in
            self?.revealClearBackground()
        }
    }

    private func applyHUD(geometry: NotchGeometry, animated: Bool) {
        removeDismissMonitors()
        // Fenêtre qui entoure l'encoche (plus large des deux côtés), barre fine en dessous.
        let size = CGSize(
            width: max(NotchWindowLayout.hudMinWidth, controller.notchWidth + NotchWindowLayout.hudSideMargin),
            height: controller.notchHeight + NotchWindowLayout.hudBottomMargin
        )
        transitionFrame(
            to: makeFrame(size: size, geometry: geometry),
            duration: NotchWindowLayout.peekDuration * controller.animationScale,
            animated: animated
        ) { [weak self] in
            self?.revealClearBackground()
        }
    }

    private func applyAmbient(geometry: NotchGeometry, animated: Bool) {
        removeDismissMonitors()
        // Pills latérales : même hauteur que l'encoche, plus large des deux côtés.
        let pillWidth = NotchController.ambientPillWidth
        let pillGap = NotchController.ambientPillGap
        let size = CGSize(
            width: controller.notchWidth + (pillWidth + pillGap) * 2,
            height: controller.notchHeight
        )
        transitionFrame(
            to: makeFrame(size: size, geometry: geometry),
            duration: NotchWindowLayout.ambientDuration * controller.animationScale,
            animated: animated
        ) { [weak self] in
            self?.revealClearBackground()
        }
    }

    private func applyCollapsed(geometry: NotchGeometry, from: NotchState, animated: Bool) {
        removeDismissMonitors()
        let size = collapsedSize(for: geometry)
        guard animated else {
            backgroundColor = .clear
            applyFrame(size: size, geometry: geometry)
            return
        }
        let frame = makeFrame(size: size, geometry: geometry)
        if from == .expanded {
            // Fermeture symétrique à l'ouverture : la fenêtre se rétracte, puis redevient transparente.
            transitionFrame(
                to: frame,
                duration: NotchWindowLayout.closeDuration * controller.animationScale,
                animated: true
            ) { [weak self] in
                self?.revealClearBackground()
            }
        } else {
            // Depuis peek / hud / ambient : rétrécir directement, fond déjà transparent.
            transitionFrame(
                to: frame,
                duration: NotchWindowLayout.peekDuration * controller.animationScale,
                animated: true
            ) { [weak self] in
                self?.updateTrackingArea()
            }
        }
    }

    private func collapsedSize(for geometry: NotchGeometry) -> CGSize {
        let ringInset = controller.timerRingActive ? NotchController.timerRingInset : 0
        let horizontalInset = max(ringInset, controller.hotZoneHorizontalInset)
        let bottomInset = max(ringInset, controller.hotZoneBottomInset)
        return CGSize(
            width: geometry.notchRect.width + horizontalInset * 2,
            height: geometry.notchRect.height + bottomInset
        )
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
        fileDragMonitor.start(
            zone: { [weak self] in self?.fileDragZone },
            onChange: { [weak self] isInside in
                guard let self else { return }
                if isInside {
                    let dropzoneID = controller.modules.first(where: { $0.id == "dropzone" })?.id ?? "dropzone"
                    controller.dragApproachNotch(preferredModuleID: dropzoneID)
                } else {
                    controller.dragLeftProximity()
                }
            }
        )
    }

    private var fileDragZone: CGRect? {
        guard let geometry = currentGeometry else { return nil }
        return CGRect(
            x: geometry.anchorPoint.x - controller.expandedWidth / 2,
            y: geometry.notchRect.minY - 120,
            width: controller.expandedWidth,
            height: 120 + geometry.notchRect.height
        )
    }

    // MARK: — Fermeture clavier et clic extérieur

    private func addDismissMonitors() {
        dismissMonitor.start(window: self) { [weak self] in
            self?.controller.dismiss()
        }
    }

    private func removeDismissMonitors() {
        dismissMonitor.stop()
    }

    // MARK: — Plein écran

    private func handleFullscreenChange(_ isFullscreen: Bool) {
        isTargetScreenFullscreen = isFullscreen
        controller.updateFullscreenStatus(isActive: isFullscreen)
        applyFullscreenVisibility()
    }

    private func applyFullscreenVisibility() {
        if isTargetScreenFullscreen, controller.fullscreenBehavior == .hidden {
            orderOut(nil)
        } else {
            orderFrontRegardless()
        }
    }
}
