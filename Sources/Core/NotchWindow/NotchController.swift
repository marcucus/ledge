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
    /// Contenu HUD courant (volume / luminosité). Nil = pas de HUD.
    public private(set) var hudContent: HUDContent?
    private var collapseTask: Task<Void, Never>?
    private var hudTask: Task<Void, Never>?
    @ObservationIgnored private var isDragHovering = false

    private let settings: SettingsStore

    /// Modules réellement affichés : catalogue filtré (activés) et trié selon les réglages.
    /// Recalculé à la lecture → la NavBar réagit à chaud aux changements de `SettingsStore`.
    public var visibleModules: [any NotchModule] {
        let order = settings.moduleOrder
        return modules
            .filter { settings.isModuleEnabled($0.id) }
            .sorted { (order.firstIndex(of: $0.id) ?? .max) < (order.firstIndex(of: $1.id) ?? .max) }
    }

    public var selectedModule: (any NotchModule)? {
        visibleModules.first { $0.id == selectedModuleID } ?? visibleModules.first
    }

    /// Largeur du panneau selon le réglage panelWidth (compact/standard/large).
    public var expandedWidth: CGFloat {
        switch settings.panelWidth {
        case .compact: 580
        case .standard: 744
        case .large: 920
        }
    }

    /// Rayon des coins bas du panneau.
    public var panelCornerRadius: CGFloat { CGFloat(settings.cornerRadius) }

    /// Comportement plein écran courant.
    public var fullscreenBehavior: FullscreenBehavior { settings.fullscreenBehavior }

    /// Afficher les libellés texte sous les icônes de modules dans la NavBar.
    public var showModuleLabels: Bool { settings.showModuleLabels }

    /// Nom de l'écran cible ("" = auto, i.e. écran avec encoche).
    public var targetScreenName: String { settings.targetScreenName }

    public init(settings: SettingsStore) {
        self.settings = settings
    }

    public func register(modules: [any NotchModule]) {
        self.modules = modules
        selectedModuleID = visibleModules.first?.id ?? ""
        modules.forEach { $0.start() }
    }

    public func selectModule(id: String) {
        guard modules.contains(where: { $0.id == id }) else { return }
        selectedModuleID = id
    }

    // MARK: — HUD

    public func showHUD(_ content: HUDContent) {
        hudContent = content
        hudTask?.cancel()
        guard state != .expanded else { return }
        if state == .collapsed || state == .hud {
            transition(to: .hud)
        }
        hudTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1600))
            guard let self, !Task.isCancelled else { return }
            hudContent = nil
            if state == .hud {
                transition(to: .collapsed)
            }
        }
    }

    public func cursorEntered() {
        collapseTask?.cancel()
        hudTask?.cancel()
        hudContent = nil
        guard state == .collapsed || state == .peeking || state == .hud else { return }

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
            transition(to: .collapsed)
        }
    }

    public func cursorExited() {
        guard state != .collapsed, !isDragHovering else { return }
        collapseTask?.cancel()
        collapseTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.settings.collapseDelay ?? 0.6))
            guard let self, !Task.isCancelled else { return }
            transition(to: .collapsed)
        }
    }

    public func panelClicked() {
        collapseTask?.cancel()
        if state == .collapsed {
    
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

