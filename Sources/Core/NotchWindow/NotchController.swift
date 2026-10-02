import SwiftUI
import Foundation

// La machine à états centralise volontairement les transitions, l'ambient, le HUD et le plein écran.
// swiftlint:disable:next type_body_length
@MainActor @Observable public final class NotchController {
    public private(set) var state: NotchState = .collapsed
    public private(set) var modules: [any NotchModule] = []
    public private(set) var selectedModuleID: String = ""
    /// Devient vrai une fois l'expansion géométrique de la fenêtre terminée. Le contenu lourd
    /// attend ce signal pour ne pas se recomposer pendant le redimensionnement AppKit.
    public private(set) var isExpansionSettled = false
    public var notchWidth: CGFloat = NotchGeometry.fallbackSize.width
    public var notchHeight: CGFloat = NotchGeometry.fallbackSize.height
    public internal(set) var usesExternalDisplayIndicator = false

    public var onTransition: ((NotchState) -> Void)?
    public var openSettings: (() -> Void)?
    /// Module affiché à droite de la NavBar (batterie, statut système…)
    public var statusModule: (any NotchModule)?
    /// Appelé quand un drag de fichier entre/quitte la zone de proximité.
    public var onDragHoverChange: ((Bool) -> Void)?
    /// Contenu HUD courant (volume / luminosité). Nil = pas de HUD.
    public internal(set) var hudContent: HUDContent?
    /// Contenu ambient actif (musique, timer…). Nil = pas d'état ambient.
    public internal(set) var ambientContent: AmbientContent?
    var ambientSources: [String: (priority: Int, content: AmbientContent)] = [:]
    var collapseTask: Task<Void, Never>?
    var hudTask: Task<Void, Never>?
    @ObservationIgnored private var isDragHovering = false
    @ObservationIgnored private var dragHoveredModuleID: String?
    @ObservationIgnored private var isPointerInsidePanel = false
    @ObservationIgnored private var isTransientInteractionActive = false
    @ObservationIgnored private var isSuppressingFullscreenContent = false
    /// Identifiants des modules réellement démarrés (`start()` appelé, `stop()` pas encore).
    /// Source de vérité du cycle de vie : distincte de `visibleModules`, qui ne pilote que l'UI.
    /// Voir `NotchController+ModuleLifecycle.swift`. `internal` (pas `private`) : lu/écrit depuis
    /// cette extension, dans un autre fichier du même module.
    @ObservationIgnored var startedModuleIDs: Set<String> = []

    /// Largeur d'une pill ambient (pixel, même dans NotchWindow Layout).
    public static let ambientPillWidth: CGFloat = 44
    /// Espace entre la pill et le bord de l'encoche.
    public static let ambientPillGap: CGFloat = 4
    /// Inset du ring timer autour de l'encoche.
    public static let timerRingInset: CGFloat = 6

    let settings: SettingsStore
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
    /// `internal` : aussi utilisée par `NotchController+ModuleLifecycle.swift`.
    func moduleVisibilityRules() -> (order: [String], isEnabled: (any NotchModule) -> Bool) {
        if let bundleID = activeBundleID,
           let profile = settings.appProfiles.first(where: { $0.bundleID == bundleID }) {
            return (profile.moduleOrder, { !profile.disabledModuleIDs.contains($0.id) })
        }
        return (settings.moduleOrder, { [settings] module in settings.isModuleEnabled(module.id) })
    }

    var contentModules: [any NotchModule] {
        navigationModules + gridModules
    }

    public var selectedModule: (any NotchModule)? {
        contentModules.first { $0.id == selectedModuleID } ?? contentModules.first
    }

    public var activeModuleID: String { selectedModule?.id ?? "" }

    /// Modules affichés directement sur les épaules de l'encoche pour la composition courante.
    public var navigationModules: [any NotchModule] {
        modules(placedIn: .bar)
    }

    /// Modules rangés dans le lanceur en grille pour la composition courante.
    public var gridModules: [any NotchModule] {
        modules(placedIn: .grid)
    }

    public var showsModuleGrid: Bool {
        settings.showsModuleGrid(in: panelComposition) && !gridModules.isEmpty
    }

    /// Composition choisie dans Réglages → Apparence.
    public var panelComposition: PanelComposition { settings.panelComposition }

    private func modules(placedIn placement: ModulePlacement) -> [any NotchModule] {
        let order = settings.moduleOrder(in: panelComposition)
        return visibleModules
            .filter { settings.modulePlacement($0.id, in: panelComposition) == placement }
            .sorted {
                (order.firstIndex(of: $0.id) ?? .max) < (order.firstIndex(of: $1.id) ?? .max)
            }
    }

    /// Largeur du panneau selon la composition choisie.
    public var expandedWidth: CGFloat {
        switch panelComposition {
        case .focused: 580
        case .panoramic: 920
        case .immersive: 744
        }
    }

    /// Hauteur de navigation, intégrée aux épaules de l'encoche.
    public var navigationHeight: CGFloat {
        switch panelComposition {
        case .focused: 44
        case .panoramic: 58
        case .immersive: 52
        }
    }

    /// Hauteur de contenu laissant plus de place au mode immersif.
    public var expandedContentHeight: CGFloat {
        switch panelComposition {
        case .focused: 200
        case .panoramic: 220
        case .immersive: 320
        }
    }

    /// Rayon des coins bas du panneau.
    public var panelCornerRadius: CGFloat { CGFloat(settings.cornerRadius) }

    /// Couleur principale de l'app (HUD + timer ring + accents).
    public var appAccentColor: Color { settings.hudAccentColor }

    /// Facteur de vitesse pour toutes les animations.
    public var animationScale: Double { settings.animationSpeed.scale }

    /// Opacité du fond du panneau (hors état collapsed).
    public var panelBackgroundOpacity: Double { max(settings.panelOpacity, 0.92) }

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

    /// Progression écoulée du timer affiché autour de l'encoche, entre 0 et 1.
    public var timerRingProgress: Double? {
        guard timerRingActive else { return nil }
        for source in ambientSources.values {
            if case let .timer(_, remainingProgress) = source.content.kind {
                return min(1, max(0, 1 - remainingProgress))
            }
        }
        return nil
    }

    public var hotZoneHorizontalInset: CGFloat { settings.hotZoneSize.horizontalInset }

    public var hotZoneBottomInset: CGFloat { settings.hotZoneSize.bottomInset }

    /// Comportement plein écran courant.
    public var fullscreenBehavior: FullscreenBehavior { settings.fullscreenBehavior }

    /// Identifiant de l'écran cible ("" = écran intégré avec encoche, automatiquement).
    public var targetScreenIdentifier: String { settings.targetScreenIdentifier }

    /// Nom historique de l'écran cible, utilisé comme secours pour migrer les réglages existants.
    public var targetScreenName: String { settings.targetScreenName }

    public init(settings: SettingsStore) {
        self.settings = settings
    }

    public func register(modules: [any NotchModule]) {
        self.modules = modules
        selectedModuleID = contentModules.first?.id ?? ""
        refreshModuleActivation()
    }

    /// Configure un rendu déterministe destiné aux captures marketing. Cette voie interne au
    /// package évite de démarrer les observateurs des modules et n'est jamais appelée par l'app.
    package func configureMarketingCapture(
        modules: [any NotchModule],
        selectedModuleID: String,
        state: NotchState,
        ambientContent: AmbientContent? = nil
    ) {
        self.modules = modules
        self.selectedModuleID = selectedModuleID
        self.state = state
        self.ambientContent = ambientContent
        isExpansionSettled = state == .expanded
    }

    // MARK: — Cycle de vie des modules : voir `NotchController+ModuleLifecycle.swift`.

    public func selectModule(id: String) {
        guard contentModules.contains(where: { $0.id == id }) else { return }
        selectedModuleID = id
    }

    /// Met à jour la bundle ID de l'app au premier plan, utilisée pour résoudre un éventuel
    /// `AppProfile` dans `visibleModules`. À appeler depuis `FrontmostAppObserver.onActiveAppChange`.
    public func updateActiveProfile(bundleID: String?) {
        guard bundleID != activeBundleID else { return }
        activeBundleID = bundleID
        applyModuleActivation()
        if !contentModules.contains(where: { $0.id == selectedModuleID }) {
            selectedModuleID = contentModules.first?.id ?? ""
        }
    }

    public func cursorEntered() {
        isPointerInsidePanel = true
        collapseTask?.cancel()
        hudTask?.cancel()
        hudContent = nil
        guard state == .collapsed || state == .peeking || state == .hud || state == .ambient else { return }
        transition(to: .expanded)
    }

    // MARK: — Drag file approach

    /// Appelé quand un drag de fichier entre dans la zone de proximité de l'encoche.
    public func dragApproachNotch(preferredModuleID: String) {
        guard startedModuleIDs.contains(preferredModuleID) else { return }
        guard !isDragHovering else { return }
        isDragHovering = true
        dragHoveredModuleID = preferredModuleID
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
        dragHoveredModuleID = nil
        onDragHoverChange?(false)
        collapseTask?.cancel()
        collapseTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, !Task.isCancelled else { return }
            transition(to: fallbackState)
        }
    }

    /// Termine immédiatement un drag piloté par un module qui vient d'être désactivé.
    func moduleDidStop(id: String) {
        guard isDragHovering, dragHoveredModuleID == id else { return }
        isDragHovering = false
        dragHoveredModuleID = nil
        onDragHoverChange?(false)
        collapseTask?.cancel()
        transition(to: fallbackState)
    }

    public func cursorExited() {
        isPointerInsidePanel = false
        // Le HUD se ferme via son propre hudTask, pas via le tracking curseur.
        guard state != .collapsed,
              state != .ambient,
              state != .hud,
              !isDragHovering,
              !isTransientInteractionActive
        else { return }
        scheduleCollapse()
    }

    /// Maintient le panneau ouvert pendant une interaction présentée hors de sa fenêtre
    /// (par exemple le popover de la grille de modules).
    public func setTransientInteractionActive(_ isActive: Bool) {
        isTransientInteractionActive = isActive
        collapseTask?.cancel()
        guard !isActive, !isPointerInsidePanel else { return }
        scheduleCollapse()
    }

    private func scheduleCollapse() {
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

    /// Applique la politique plein écran sans modifier le comportement normal au survol.
    public func updateFullscreenStatus(isActive: Bool) {
        let wasSuppressing = isSuppressingFullscreenContent
        isSuppressingFullscreenContent = isActive && settings.fullscreenBehavior != .overlay

        if isSuppressingFullscreenContent {
            collapseTask?.cancel()
            hudTask?.cancel()
            hudContent = nil
            transition(to: .collapsed)
        } else if wasSuppressing, state == .collapsed {
            transition(to: fallbackState)
        }
    }

    /// État de repli en quittant expanded/peek/hud : ambient si un contenu doit y être montré,
    /// sinon collapsed. Un timer en mode anneau ne compte pas (il reste collapsed, l'anneau suffit).
    var fallbackState: NotchState {
        guard !suppressesTransientContentInFullscreen else { return .collapsed }
        guard let content = ambientContent else { return .collapsed }
        if case .timer = content.kind, settings.showRingWhenTimerActive { return .collapsed }
        return .ambient
    }

    var suppressesTransientContentInFullscreen: Bool {
        isSuppressingFullscreenContent
    }

    func transition(to newState: NotchState) {
        guard newState != state else { return }
        // Ce drapeau ne pilote que l'entrée. Le conserver pendant la sortie laisse SwiftUI
        // rejouer exactement la transition de fermeture historique, sans animation concurrente.
        if newState == .expanded {
            isExpansionSettled = false
        }
        state = newState
        onTransition?(newState)
    }

    func expansionDidFinish() {
        guard state == .expanded else { return }
        isExpansionSettled = true
    }
}
