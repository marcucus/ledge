import SwiftUI
import Foundation

@MainActor @Observable public final class NotchController {
    public private(set) var state: NotchState = .collapsed
    public private(set) var modules: [any NotchModule] = []
    public private(set) var selectedModuleID: String = ""
    public var notchWidth: CGFloat = NotchGeometry.fallbackSize.width
    public var notchHeight: CGFloat = NotchGeometry.fallbackSize.height

    public var onTransition: ((NotchState) -> Void)?
    public var openSettings: (() -> Void)?
    /// Module affiché à droite de la NavBar (batterie, statut système…)
    public var statusModule: (any NotchModule)?
    /// Appelé quand un drag de fichier entre/quitte la zone de proximité.
    public var onDragHoverChange: ((Bool) -> Void)?
    /// Contenu HUD courant (volume / luminosité). Nil = pas de HUD.
    public private(set) var hudContent: HUDContent?
    /// Contenu ambient actif (musique, timer…). Nil = pas d'état ambient.
    public private(set) var ambientContent: AmbientContent?
    private var ambientSources: [String: (priority: Int, content: AmbientContent)] = [:]
    private var collapseTask: Task<Void, Never>?
    private var hudTask: Task<Void, Never>?
    @ObservationIgnored private var isDragHovering = false

    /// Largeur d'une pill ambient (pixel, même dans NotchWindow Layout).
    public static let ambientPillWidth: CGFloat = 44
    /// Espace entre la pill et le bord de l'encoche.
    public static let ambientPillGap: CGFloat = 4
    /// Inset du ring timer autour de l'encoche.
    public static let timerRingInset: CGFloat = 6

    private let settings: SettingsStore
    /// Bundle ID de l'app au premier plan, fournie par `updateActiveProfile`. Nil = aucune app
    /// suivie ou aucun profil ne s'applique : le comportement global (réglages) prévaut.
    private var activeBundleID: String?

    /// Modules réellement affichés : catalogue filtré (activés) et trié selon les réglages,
    /// ou selon le profil d'app actif s'il y en a un (voir `updateActiveProfile`).
    /// Recalculé à la lecture → la NavBar réagit à chaud aux changements de `SettingsStore`.
    public var visibleModules: [any NotchModule] {
        let (order, isEnabled) = moduleVisibilityRules()
        return modules
            .filter(isEnabled)
            .sorted { (order.firstIndex(of: $0.id) ?? .max) < (order.firstIndex(of: $1.id) ?? .max) }
    }

    /// Ordre et règle d'activation à appliquer : ceux du profil actif si un `AppProfile`
    /// correspond à `activeBundleID`, sinon les réglages globaux (`SettingsStore`).
    private func moduleVisibilityRules() -> (order: [String], isEnabled: (any NotchModule) -> Bool) {
        if let bundleID = activeBundleID,
           let profile = settings.appProfiles.first(where: { $0.bundleID == bundleID }) {
            return (profile.moduleOrder, { !profile.disabledModuleIDs.contains($0.id) })
        }
        return (settings.moduleOrder, { [settings] module in settings.isModuleEnabled(module.id) })
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

    /// Couleur principale de l'app (HUD + timer ring + accents).
    public var appAccentColor: Color { settings.hudAccentColor }

    /// Facteur de vitesse pour toutes les animations.
    public var animationScale: Double { settings.animationSpeed.scale }

    /// Opacité du fond du panneau (hors état collapsed).
    public var panelBackgroundOpacity: Double { settings.panelOpacity }

    /// Afficher la pochette dans l'ambient.
    public var ambientShowArtwork: Bool { settings.ambientShowArtwork }

    /// Afficher la barre de progression dans l'ambient.
    public var ambientShowProgress: Bool { settings.ambientShowProgress }

    /// Vrai si le timer ring doit être affiché (timer actif + réglage activé).
    public var timerRingActive: Bool {
        guard settings.showRingWhenTimerActive else { return false }
        return ambientSources.values.contains { pair in
            if case .timer = pair.content.kind { return true }
            return false
        }
    }

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

    /// Met à jour la bundle ID de l'app au premier plan, utilisée pour résoudre un éventuel
    /// `AppProfile` dans `visibleModules`. À appeler depuis `FrontmostAppObserver.onActiveAppChange`.
    public func updateActiveProfile(bundleID: String?) {
        guard bundleID != activeBundleID else { return }
        activeBundleID = bundleID
        if !visibleModules.contains(where: { $0.id == selectedModuleID }) {
            selectedModuleID = visibleModules.first?.id ?? ""
        }
    }

    // MARK: — Ambient

    /// Enregistre ou retire un contributeur ambient. La source avec la priorité la plus haute gagne.
    public func setAmbient(_ content: AmbientContent?, sourceID: String, priority: Int) {
        let wasRingActive = timerRingActive

        if let content {
            ambientSources[sourceID] = (priority: priority, content: content)
        } else {
            ambientSources.removeValue(forKey: sourceID)
        }
        let best = ambientSources.values.max(by: { $0.priority < $1.priority })
        ambientContent = best?.content

        let bestIsTimerInRingMode: Bool
        if let c = ambientContent, case .timer = c.kind, settings.showRingWhenTimerActive {
            bestIsTimerInRingMode = true
        } else {
            bestIsTimerInRingMode = false
        }

        if ambientContent != nil && !bestIsTimerInRingMode {
            if state == .collapsed { transition(to: .ambient) }
        } else if state == .ambient {
            transition(to: .collapsed)
        }

        // Quand timerRingActive change en état collapsed, la fenêtre doit se redimensionner
        // (s'agrandir pour afficher le ring, ou rétrécir quand il s'arrête). Comme il n'y a
        // pas de transition d'état, on notifie NotchWindow directement via onTransition.
        if state == .collapsed && timerRingActive != wasRingActive {
            onTransition?(state)
        }
    }

    // MARK: — HUD

    public func showHUD(_ content: HUDContent) {
        hudTask?.cancel()
        guard state != .expanded else { return }
        hudContent = content
        if state == .collapsed || state == .hud || state == .ambient {
            transition(to: .hud)
        }
        hudTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1600))
            guard let self, !Task.isCancelled else { return }
            hudContent = nil
            if state == .hud {
                transition(to: fallbackState)
            }
        }
    }

    public func cursorEntered() {
        collapseTask?.cancel()
        hudTask?.cancel()
        hudContent = nil
        guard state == .collapsed || state == .peeking || state == .hud || state == .ambient else { return }
        transition(to: .expanded)
    }

    // MARK: — Drag file approach

    /// Appelé quand un drag de fichier entre dans la zone de proximité de l'encoche.
    public func dragApproachNotch(preferredModuleID: String) {
        guard !isDragHovering else { return }
        isDragHovering = true
        collapseTask?.cancel()
        selectModule(id: preferredModuleID)
        if state == .collapsed || state == .ambient {
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
            transition(to: fallbackState)
        }
    }

    public func cursorExited() {
        // Le HUD se ferme via son propre hudTask, pas via le tracking curseur.
        guard state != .collapsed, state != .ambient, state != .hud, !isDragHovering else { return }
        collapseTask?.cancel()
        collapseTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.settings.collapseDelay ?? 0.6))
            guard let self, !Task.isCancelled else { return }
            transition(to: fallbackState)
        }
    }

    public func panelClicked() {
        collapseTask?.cancel()
        if state == .collapsed || state == .ambient {
            let target: NotchState = settings.clickBehavior == .peek ? .peeking : .expanded
            transition(to: target)
        } else {
            dismiss()
        }
    }

    public func dismiss() {
        collapseTask?.cancel()
        transition(to: fallbackState)
    }

    /// État de repli en quittant expanded/peek/hud : ambient si un contenu doit y être montré,
    /// sinon collapsed. Un timer en mode anneau ne compte pas (il reste collapsed, l'anneau suffit).
    private var fallbackState: NotchState {
        guard let content = ambientContent else { return .collapsed }
        if case .timer = content.kind, settings.showRingWhenTimerActive { return .collapsed }
        return .ambient
    }

    private func transition(to newState: NotchState) {
        guard newState != state else { return }
        state = newState
        onTransition?(newState)
    }
}
