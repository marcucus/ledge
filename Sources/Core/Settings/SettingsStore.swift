import Foundation
import SwiftUI

@Observable public final class SettingsStore {
    public static let shared = SettingsStore()

    // Accès `internal` (plutôt que `private`) pour rester lisible depuis
    // `SettingsStore+Reset.swift` (doc 13, Jalon 4, item 27).
    let defaults: UserDefaults

    // "system" est volontairement absent : jamais enregistré comme onglet (ModuleCatalog).
    public static let defaultModuleOrder = [
        "media", "timers", "dropzone", "clipboard", "shortcuts", "calendar", "notes",
    ]

    // MARK: — General

    public var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    public var collapseDelay: Double {
        didSet { defaults.set(collapseDelay, forKey: Keys.collapseDelay) }
    }

    public var hotZoneSize: HotZoneSize {
        didSet { defaults.set(hotZoneSize.rawValue, forKey: Keys.hotZoneSize) }
    }

    // MARK: — Modules

    public var moduleOrder: [String] {
        didSet { defaults.set(moduleOrder, forKey: Keys.moduleOrder) }
    }

    // Accès `internal` (plutôt que `private`) pour rester modifiable depuis
    // `SettingsStore+Reset.swift` (doc 13, Jalon 4, item 27).
    var disabledModuleIDs: Set<String> {
        didSet { defaults.set(Array(disabledModuleIDs), forKey: Keys.disabledModules) }
    }

    // MARK: — System HUD

    public var hudReplaceSystem: Bool {
        didSet { defaults.set(hudReplaceSystem, forKey: Keys.hudReplaceSystem) }
    }

    /// Si vrai, le HUD de luminosité n'apparaît que pour les touches clavier (pas l'auto-ajustement).
    public var hudBrightnessManualOnly: Bool {
        didSet { defaults.set(hudBrightnessManualOnly, forKey: Keys.hudBrightnessManualOnly) }
    }

    // MARK: — Appearance

    public var hudUseSystemAccent: Bool {
        didSet { defaults.set(hudUseSystemAccent, forKey: Keys.hudUseSystemAccent) }
    }

    public var hudAccentColorComponents: [Double] {
        didSet { defaults.set(hudAccentColorComponents, forKey: Keys.hudAccentColorComponents) }
    }

    public var hudAccentColor: Color {
        if hudUseSystemAccent || hudAccentColorComponents.count < 3 {
            return Color.accentColor
        }
        return Color(
            red: hudAccentColorComponents[0],
            green: hudAccentColorComponents[1],
            blue: hudAccentColorComponents[2]
        )
    }

    public var panelComposition: PanelComposition {
        didSet { defaults.set(panelComposition.rawValue, forKey: Keys.panelComposition) }
    }

    var focusedModulePlacements: [String: Int] {
        didSet { defaults.set(focusedModulePlacements, forKey: Keys.focusedModulePlacements) }
    }

    var panoramicModulePlacements: [String: Int] {
        didSet { defaults.set(panoramicModulePlacements, forKey: Keys.panoramicModulePlacements) }
    }

    var immersiveModulePlacements: [String: Int] {
        didSet { defaults.set(immersiveModulePlacements, forKey: Keys.immersiveModulePlacements) }
    }

    var focusedShowsModuleGrid: Bool {
        didSet { defaults.set(focusedShowsModuleGrid, forKey: Keys.focusedShowsModuleGrid) }
    }

    var panoramicShowsModuleGrid: Bool {
        didSet { defaults.set(panoramicShowsModuleGrid, forKey: Keys.panoramicShowsModuleGrid) }
    }

    var immersiveShowsModuleGrid: Bool {
        didSet { defaults.set(immersiveShowsModuleGrid, forKey: Keys.immersiveShowsModuleGrid) }
    }

    var compositionModuleOrders: CompositionModuleOrders {
        didSet { defaults.setCodable(compositionModuleOrders, forKey: Keys.compositionModuleOrders) }
    }

    public var cornerRadius: Double {
        didSet { defaults.set(cornerRadius, forKey: Keys.cornerRadius) }
    }

    public var panelOpacity: Double {
        didSet { defaults.set(panelOpacity, forKey: Keys.panelOpacity) }
    }

    // MARK: — Display

    public var notchDetectionMode: NotchDetectionMode {
        didSet { defaults.set(notchDetectionMode.rawValue, forKey: Keys.notchDetectionMode) }
    }

    public var fullscreenBehavior: FullscreenBehavior {
        didSet { defaults.set(fullscreenBehavior.rawValue, forKey: Keys.fullscreenBehavior) }
    }

    public var showRingWhenTimerActive: Bool {
        didSet { defaults.set(showRingWhenTimerActive, forKey: Keys.showRingWhenTimerActive) }
    }

    // MARK: — Animations

    public var animationSpeed: AnimationSpeed {
        didSet { defaults.set(animationSpeed.rawValue, forKey: Keys.animationSpeed) }
    }

    // MARK: — Click behavior

    public var clickBehavior: ClickBehavior {
        didSet { defaults.set(clickBehavior.rawValue, forKey: Keys.clickBehavior) }
    }

    // MARK: — Shortcuts

    public var globalShortcutEnabled: Bool {
        didSet { defaults.set(globalShortcutEnabled, forKey: Keys.globalShortcutEnabled) }
    }

    /// Identifiants des actions dont la combinaison n'a pas pu être enregistrée auprès de
    /// macOS (déjà utilisée par une autre app, doublon interne ou combinaison invalide).
    /// État de session uniquement : `GlobalShortcutManager` le recalcule à chaque application.
    public internal(set) var globalShortcutConflictIDs: Set<String> = []

    public var shortcutOpenClose: GlobalKeyboardShortcut {
        didSet { defaults.setShortcut(shortcutOpenClose, forKey: Keys.shortcutOpenClose) }
    }

    public var shortcutPaste: GlobalKeyboardShortcut {
        didSet { defaults.setShortcut(shortcutPaste, forKey: Keys.shortcutPaste) }
    }

    public var shortcutNewTimer: GlobalKeyboardShortcut {
        didSet { defaults.setShortcut(shortcutNewTimer, forKey: Keys.shortcutNewTimer) }
    }

    public var shortcutOpenMedia: GlobalKeyboardShortcut {
        didSet { defaults.setShortcut(shortcutOpenMedia, forKey: Keys.shortcutOpenMedia) }
    }

    // MARK: — Clipboard module

    public var clipboardMaxItems: Int {
        didSet { defaults.set(clipboardMaxItems, forKey: Keys.clipboardMaxItems) }
    }

    /// Persister l'historique du presse-papiers sur disque entre les lancements.
    /// Désactivé par défaut : l'historique ne vit qu'en RAM (cf. doc 03, confidentialité).
    public var clipboardPersistEnabled: Bool {
        didSet { defaults.set(clipboardPersistEnabled, forKey: Keys.clipboardPersistEnabled) }
    }

    /// Identifiants de bundle des apps dont les copies ne sont jamais capturées (doc 13,
    /// Jalon 3, item 18). Stocke des identifiants (stables si l'app est déplacée), pas des
    /// chemins de fichiers.
    public var clipboardExcludedApps: [String] {
        didSet { defaults.set(clipboardExcludedApps, forKey: Keys.clipboardExcludedApps) }
    }

    /// État d'exécution (pas persisté) : voir `ClipboardPersistenceIssue` et
    /// `SettingsStore+ClipboardRuntime.swift`.
    public var clipboardPersistenceIssue: ClipboardPersistenceIssue?
    /// Observé par `ClipboardModule` pour retenter un persist/clear en échec (voir
    /// `requestClipboardPersistenceRetry()` dans `SettingsStore+ClipboardRuntime.swift`).
    public var clipboardPersistenceRetryToken = 0

    // MARK: — Timer / Pomodoro

    public var timerSoundEnabled: Bool {
        didSet { defaults.set(timerSoundEnabled, forKey: Keys.timerSoundEnabled) }
    }

    public var timerAlertVisualOnly: Bool {
        didSet { defaults.set(timerAlertVisualOnly, forKey: Keys.timerAlertVisualOnly) }
    }

    /// Affiche brièvement le peek du module Timer à la fin d'un minuteur, en plus de la
    /// notification système (doc 13, Jalon 3, item 20). Utile quand les notifications sont
    /// discrètes ou masquées (Ne pas déranger).
    public var timerFinishedPeekEnabled: Bool {
        didSet { defaults.set(timerFinishedPeekEnabled, forKey: Keys.timerFinishedPeekEnabled) }
    }

    public var timerFinishedPeekDuration: Double {
        didSet { defaults.set(timerFinishedPeekDuration, forKey: Keys.timerFinishedPeekDuration) }
    }

    public var pomodoroWorkDuration: Double {
        didSet { defaults.set(pomodoroWorkDuration, forKey: Keys.pomodoroWorkDuration) }
    }

    public var pomodoroShortBreakDuration: Double {
        didSet { defaults.set(pomodoroShortBreakDuration, forKey: Keys.pomodoroShortBreakDuration) }
    }

    public var pomodoroLongBreakDuration: Double {
        didSet { defaults.set(pomodoroLongBreakDuration, forKey: Keys.pomodoroLongBreakDuration) }
    }

    // MARK: — Display

    /// Identifiant CoreGraphics persistant de l'écran choisi. Vide = écran du Mac automatiquement.
    public var targetScreenIdentifier: String {
        didSet { defaults.set(targetScreenIdentifier, forKey: Keys.targetScreenIdentifier) }
    }

    /// Nom conservé pour afficher une cible temporairement déconnectée et migrer l'ancien réglage.
    public var targetScreenName: String {
        didSet { defaults.set(targetScreenName, forKey: Keys.targetScreenName) }
    }

    public var displayTargetMode: DisplayTargetMode {
        didSet { defaults.set(displayTargetMode.rawValue, forKey: Keys.displayTargetMode) }
    }

    public var selectedScreenIdentifiers: [String] {
        didSet { defaults.set(selectedScreenIdentifiers, forKey: Keys.selectedScreenIdentifiers) }
    }

    public var selectedScreenNames: [String: String] {
        didSet { defaults.set(selectedScreenNames, forKey: Keys.selectedScreenNames) }
    }

    // MARK: — Ambient / Media

    public var ambientShowArtwork: Bool {
        didSet { defaults.set(ambientShowArtwork, forKey: Keys.ambientShowArtwork) }
    }

    public var ambientShowProgress: Bool {
        didSet { defaults.set(ambientShowProgress, forKey: Keys.ambientShowProgress) }
    }

    // MARK: — DropZone

    public var dropZoneAcceptFolders: Bool {
        didSet { defaults.set(dropZoneAcceptFolders, forKey: Keys.dropZoneAcceptFolders) }
    }

    // MARK: — App profiles

    /// Profils de visibilité des modules par application au premier plan. Voir `AppProfile`.
    public var appProfiles: [AppProfile] {
        didSet { defaults.setCodable(appProfiles, forKey: Keys.appProfiles) }
    }

    // `defaults` est injectable pour les tests; en production, utiliser `SettingsStore.shared`.
    // Initialisation plate et exhaustive : la découper masquerait la source de chaque valeur.
    // swiftlint:disable:next function_body_length
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        collapseDelay = defaults.double(forKey: Keys.collapseDelay).nonZero ?? 0.6
        let storedHotZoneSize = defaults.object(forKey: Keys.hotZoneSize) as? Int
        hotZoneSize = HotZoneSize(rawValue: storedHotZoneSize ?? -1) ?? .standard
        moduleOrder = (defaults.array(forKey: Keys.moduleOrder) as? [String]) ?? Self.defaultModuleOrder
        disabledModuleIDs = Set(defaults.stringArray(forKey: Keys.disabledModules) ?? [])
        hudReplaceSystem = defaults.object(forKey: Keys.hudReplaceSystem) as? Bool ?? true
        hudBrightnessManualOnly = defaults.object(forKey: Keys.hudBrightnessManualOnly) as? Bool ?? true
        hudUseSystemAccent = defaults.object(forKey: Keys.hudUseSystemAccent) as? Bool ?? true
        hudAccentColorComponents = (defaults.array(forKey: Keys.hudAccentColorComponents) as? [Double]) ?? []
        let storedComposition = defaults.object(forKey: Keys.panelComposition) as? Int
        let legacyWidth = defaults.object(forKey: Keys.legacyPanelWidth) as? Int
        panelComposition = PanelComposition(rawValue: storedComposition ?? legacyWidth ?? -1) ?? .panoramic
        focusedModulePlacements = defaults.dictionary(forKey: Keys.focusedModulePlacements) as? [String: Int]
            ?? Self.defaultFocusedModulePlacements
        panoramicModulePlacements = defaults.dictionary(forKey: Keys.panoramicModulePlacements) as? [String: Int]
            ?? Self.defaultPanoramicModulePlacements
        immersiveModulePlacements = defaults.dictionary(forKey: Keys.immersiveModulePlacements) as? [String: Int]
            ?? Self.defaultImmersiveModulePlacements
        focusedShowsModuleGrid = defaults.object(forKey: Keys.focusedShowsModuleGrid) as? Bool ?? true
        panoramicShowsModuleGrid = defaults.object(forKey: Keys.panoramicShowsModuleGrid) as? Bool ?? false
        immersiveShowsModuleGrid = defaults.object(forKey: Keys.immersiveShowsModuleGrid) as? Bool ?? true
        compositionModuleOrders = defaults.codable(
            CompositionModuleOrders.self,
            forKey: Keys.compositionModuleOrders
        ) ?? .defaults
        cornerRadius = defaults.double(forKey: Keys.cornerRadius).nonZero ?? 12.0
        panelOpacity = max(defaults.object(forKey: Keys.panelOpacity) as? Double ?? 1.0, 0.92)
        notchDetectionMode = NotchDetectionMode(
            rawValue: defaults.integer(forKey: Keys.notchDetectionMode)
        ) ?? .automatic
        fullscreenBehavior = FullscreenBehavior(
            rawValue: defaults.integer(forKey: Keys.fullscreenBehavior)
        ) ?? .accessible
        showRingWhenTimerActive = defaults.object(forKey: Keys.showRingWhenTimerActive) as? Bool ?? false
        animationSpeed = AnimationSpeed(rawValue: defaults.object(forKey: Keys.animationSpeed) as? Int ?? -1) ?? .normal
        clickBehavior = ClickBehavior(rawValue: defaults.object(forKey: Keys.clickBehavior) as? Int ?? -1) ?? .expand
        timerSoundEnabled = defaults.object(forKey: Keys.timerSoundEnabled) as? Bool ?? true
        timerAlertVisualOnly = defaults.object(forKey: Keys.timerAlertVisualOnly) as? Bool ?? false
        timerFinishedPeekEnabled = defaults.object(forKey: Keys.timerFinishedPeekEnabled) as? Bool ?? true
        timerFinishedPeekDuration = defaults.double(forKey: Keys.timerFinishedPeekDuration).nonZero ?? 4
        globalShortcutEnabled = defaults.object(forKey: Keys.globalShortcutEnabled) as? Bool ?? true
        shortcutOpenClose = defaults.shortcut(forKey: Keys.shortcutOpenClose) ?? .defaultOpenClose
        shortcutPaste = defaults.shortcut(forKey: Keys.shortcutPaste) ?? .defaultPaste
        shortcutNewTimer = defaults.shortcut(forKey: Keys.shortcutNewTimer) ?? .defaultNewTimer
        shortcutOpenMedia = defaults.shortcut(forKey: Keys.shortcutOpenMedia) ?? .defaultOpenMedia
        clipboardMaxItems = defaults.object(forKey: Keys.clipboardMaxItems) as? Int ?? 50
        clipboardPersistEnabled = defaults.object(forKey: Keys.clipboardPersistEnabled) as? Bool ?? false
        clipboardExcludedApps = defaults.stringArray(forKey: Keys.clipboardExcludedApps) ?? []
        pomodoroWorkDuration = defaults.double(forKey: Keys.pomodoroWorkDuration).nonZero ?? 25
        pomodoroShortBreakDuration = defaults.double(forKey: Keys.pomodoroShortBreakDuration).nonZero ?? 5
        pomodoroLongBreakDuration = defaults.double(forKey: Keys.pomodoroLongBreakDuration).nonZero ?? 15
        let legacyTargetIdentifier = defaults.string(forKey: Keys.targetScreenIdentifier) ?? ""
        let legacyTargetName = defaults.string(forKey: Keys.targetScreenName) ?? ""
        targetScreenIdentifier = legacyTargetIdentifier
        targetScreenName = legacyTargetName
        let storedTargetMode = defaults.object(forKey: Keys.displayTargetMode) as? Int
        if let storedTargetMode, let mode = DisplayTargetMode(rawValue: storedTargetMode) {
            displayTargetMode = mode
        } else {
            displayTargetMode = legacyTargetIdentifier.isEmpty ? .automatic : .selected
        }
        selectedScreenIdentifiers = defaults.stringArray(forKey: Keys.selectedScreenIdentifiers)
            ?? (legacyTargetIdentifier.isEmpty ? [] : [legacyTargetIdentifier])
        selectedScreenNames = defaults.dictionary(forKey: Keys.selectedScreenNames) as? [String: String]
            ?? (legacyTargetIdentifier.isEmpty ? [:] : [legacyTargetIdentifier: legacyTargetName])
        ambientShowArtwork = defaults.object(forKey: Keys.ambientShowArtwork) as? Bool ?? true
        ambientShowProgress = defaults.object(forKey: Keys.ambientShowProgress) as? Bool ?? false
        dropZoneAcceptFolders = defaults.object(forKey: Keys.dropZoneAcceptFolders) as? Bool ?? true
        appProfiles = defaults.codable([AppProfile].self, forKey: Keys.appProfiles) ?? []
    }

    public func isModuleEnabled(_ id: String) -> Bool {
        !disabledModuleIDs.contains(id)
    }

    public func setModule(_ id: String, enabled: Bool) {
        if enabled { disabledModuleIDs.remove(id) } else { disabledModuleIDs.insert(id) }
    }
}
