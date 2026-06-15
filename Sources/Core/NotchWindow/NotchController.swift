import Foundation

@MainActor @Observable public final class NotchController {
    public private(set) var state: NotchState = .collapsed
    public private(set) var modules: [any NotchModule] = []
    public private(set) var selectedModuleID: String = ""
    public var notchWidth: CGFloat = 190
    public var notchHeight: CGFloat = 32

    public var onTransition: ((NotchState) -> Void)?
    public var openSettings: (() -> Void)?
    /// Module affiché à droite de la NavBar (batterie, statut système…)
    public var statusModule: (any NotchModule)?
    /// Appelé quand un drag de fichier entre/quitte la zone de proximité.
    public var onDragHoverChange: ((Bool) -> Void)?
    private var collapseTask: Task<Void, Never>?
    @ObservationIgnored private var lastExpandTime: TimeInterval = 0
    @ObservationIgnored private var isDragHovering = false

    public var selectedModule: (any NotchModule)? {
        modules.first { $0.id == selectedModuleID } ?? modules.first
    }

    public init() {}

    public func register(modules: [any NotchModule]) {
        self.modules = modules
        selectedModuleID = modules.first?.id ?? ""
        modules.forEach { $0.start() }
    }

    public func selectModule(id: String) {
        guard modules.contains(where: { $0.id == id }) else { return }
        selectedModuleID = id
    }

    public func cursorEntered() {
        collapseTask?.cancel()
        guard state == .collapsed else { return }
        lastExpandTime = ProcessInfo.processInfo.systemUptime
        transition(to: .expanded)
    }

    // MARK: — Drag file approach

    /// Appelé quand un drag de fichier entre dans la zone de proximité de l'encoche.
    public func dragApproachNotch(preferredModuleID: String) {
        guard !isDragHovering else { return }
        isDragHovering = true
        collapseTask?.cancel()
        selectModule(id: preferredModuleID)
        if state == .collapsed {
            lastExpandTime = ProcessInfo.processInfo.systemUptime
            transition(to: .expanded)
        }
        onDragHoverChange?(true)
    }

    /// Appelé quand le drag quitte la zone de proximité ou que le bouton est relâché.
    public func dragLeftProximity() {
        guard isDragHovering else { return }
        isDragHovering = false
        onDragHoverChange?(false)
        collapseTask?.cancel()
        collapseTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, !Task.isCancelled else { return }
            self.transition(to: .collapsed)
        }
    }

    public func cursorExited() {
        guard state != .collapsed, !isDragHovering else { return }
        collapseTask?.cancel()
        // Ignore les mouseExited spurieux qui arrivent juste après l'expansion
        // (causés par le recalcul de la tracking area pendant l'animation)
        let elapsed = ProcessInfo.processInfo.systemUptime - lastExpandTime
        guard elapsed > 0.45 else { return }
        collapseTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Timing.collapseDelay))
            guard let self, !Task.isCancelled else { return }
            self.transition(to: .collapsed)
        }
    }

    public func panelClicked() {
        collapseTask?.cancel()
        if state == .collapsed {
            lastExpandTime = ProcessInfo.processInfo.systemUptime
            transition(to: .expanded)
        } else {
            dismiss()
        }
    }

    public func dismiss() {
        collapseTask?.cancel()
        transition(to: .collapsed)
    }

    private func transition(to newState: NotchState) {
        guard newState != state else { return }
        state = newState
        onTransition?(newState)
    }
}

private enum Timing {
    static let collapseDelay: TimeInterval = 0.6
}
