import Foundation
import SwiftUI

@Observable public final class SettingsStore {
    public static let shared = SettingsStore()

    private let defaults: UserDefaults

    public static let defaultModuleOrder = [
        "media", "timers", "dropzone", "clipboard", "system", "shortcuts", "calendar", "notes",
    ]

    // MARK: — General

    public var collapseDelay: Double {
        didSet { defaults.set(collapseDelay, forKey: Keys.collapseDelay) }
    }

    // MARK: — Modules

    public var moduleOrder: [String] {
        didSet { defaults.set(moduleOrder, forKey: Keys.moduleOrder) }
    }

    private var disabledModuleIDs: Set<String> {
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

    public var panelWidth: PanelWidth {
        didSet { defaults.set(panelWidth.rawValue, forKey: Keys.panelWidth) }
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

    // MARK: — NavBar

    public var showModuleLabels: Bool {
        didSet { defaults.set(showModuleLabels, forKey: Keys.showModuleLabels) }
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

    // MARK: — Timer / Pomodoro

    public var timerSoundEnabled: Bool {
        didSet { defaults.set(timerSoundEnabled, forKey: Keys.timerSoundEnabled) }
    }

    public var timerAlertVisualOnly: Bool {
        didSet { defaults.set(timerAlertVisualOnly, forKey: Keys.timerAlertVisualOnly) }
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

    public var targetScreenName: String {
        didSet { defaults.set(targetScreenName, forKey: Keys.targetScreenName) }
    }

    // MARK: — System launcher

    public var launcherApps: [String] {
        didSet { defaults.set(launcherApps, forKey: Keys.launcherApps) }
    }

    // MARK: — Ambient / Media

    public var ambientShowArtwork: Bool {
        didSet { defaults.set(ambientShowArtwork, forKey: Keys.ambientShowArtwork) }
    }

    public var ambientShowProgress: Bool {
        didSet { defaults.set(ambientShowProgress, forKey: Keys.ambientShowProgress) }
    }

    // MARK: — System gauges

    public var systemShowCPU: Bool {
        didSet { defaults.set(systemShowCPU, forKey: Keys.systemShowCPU) }
    }

    public var systemShowRAM: Bool {
        didSet { defaults.set(systemShowRAM, forKey: Keys.systemShowRAM) }
    }

    public var systemShowBattery: Bool {
        didSet { defaults.set(systemShowBattery, forKey: Keys.systemShowBattery) }
    }

    public var systemShowNetwork: Bool {
        didSet { defaults.set(systemShowNetwork, forKey: Keys.systemShowNetwork) }
    }

    /// Indicateur de confidentialité : micro en cours d'utilisation.
    public var systemShowMicrophoneIndicator: Bool {
        didSet { defaults.set(systemShowMicrophoneIndicator, forKey: Keys.systemShowMicrophoneIndicator) }
    }

    /// Jauge batterie des accessoires Bluetooth (AirPods, souris, clavier…).
    public var systemShowAccessoryBattery: Bool {
        didSet { defaults.set(systemShowAccessoryBattery, forKey: Keys.systemShowAccessoryBattery) }
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

    /// `defaults` injectable pour les tests (instance isolée, ex. `UserDefaults(suiteName:)`) —
    /// en production, utiliser `SettingsStore.shared` plutôt que d'instancier directement.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        collapseDelay = defaults.double(forKey: Keys.collapseDelay).nonZero ?? 0.6
        moduleOrder = (defaults.array(forKey: Keys.moduleOrder) as? [String]) ?? Self.defaultModuleOrder
        disabledModuleIDs = Set(defaults.stringArray(forKey: Keys.disabledModules) ?? [])
        hudReplaceSystem = defaults.object(forKey: Keys.hudReplaceSystem) as? Bool ?? true
        hudBrightnessManualOnly = defaults.object(forKey: Keys.hudBrightnessManualOnly) as? Bool ?? true
        hudUseSystemAccent = defaults.object(forKey: Keys.hudUseSystemAccent) as? Bool ?? true
        hudAccentColorComponents = (defaults.array(forKey: Keys.hudAccentColorComponents) as? [Double]) ?? []
        panelWidth = PanelWidth(rawValue: defaults.integer(forKey: Keys.panelWidth)) ?? .standard
        cornerRadius = defaults.double(forKey: Keys.cornerRadius).nonZero ?? 12.0
        panelOpacity = defaults.object(forKey: Keys.panelOpacity) as? Double ?? 1.0
        notchDetectionMode = NotchDetectionMode(rawValue: defaults.integer(forKey: Keys.notchDetectionMode)) ?? .automatic
        fullscreenBehavior = FullscreenBehavior(rawValue: defaults.integer(forKey: Keys.fullscreenBehavior)) ?? .accessible
        showRingWhenTimerActive = defaults.object(forKey: Keys.showRingWhenTimerActive) as? Bool ?? false
        animationSpeed = AnimationSpeed(rawValue: defaults.object(forKey: Keys.animationSpeed) as? Int ?? -1) ?? .normal
        clickBehavior = ClickBehavior(rawValue: defaults.object(forKey: Keys.clickBehavior) as? Int ?? -1) ?? .expand
        timerSoundEnabled = defaults.object(forKey: Keys.timerSoundEnabled) as? Bool ?? true
        timerAlertVisualOnly = defaults.object(forKey: Keys.timerAlertVisualOnly) as? Bool ?? false
        globalShortcutEnabled = defaults.object(forKey: Keys.globalShortcutEnabled) as? Bool ?? true
        shortcutOpenClose = defaults.shortcut(forKey: Keys.shortcutOpenClose) ?? .defaultOpenClose
        shortcutPaste = defaults.shortcut(forKey: Keys.shortcutPaste) ?? .defaultPaste
        shortcutNewTimer = defaults.shortcut(forKey: Keys.shortcutNewTimer) ?? .defaultNewTimer
        shortcutOpenMedia = defaults.shortcut(forKey: Keys.shortcutOpenMedia) ?? .defaultOpenMedia
        showModuleLabels = defaults.object(forKey: Keys.showModuleLabels) as? Bool ?? false
        clipboardMaxItems = defaults.object(forKey: Keys.clipboardMaxItems) as? Int ?? 50
        clipboardPersistEnabled = defaults.object(forKey: Keys.clipboardPersistEnabled) as? Bool ?? false
        pomodoroWorkDuration = defaults.double(forKey: Keys.pomodoroWorkDuration).nonZero ?? 25
        pomodoroShortBreakDuration = defaults.double(forKey: Keys.pomodoroShortBreakDuration).nonZero ?? 5
        pomodoroLongBreakDuration = defaults.double(forKey: Keys.pomodoroLongBreakDuration).nonZero ?? 15
        targetScreenName = defaults.string(forKey: Keys.targetScreenName) ?? ""
        launcherApps = (defaults.stringArray(forKey: Keys.launcherApps)) ?? Self.defaultLauncherApps
        ambientShowArtwork = defaults.object(forKey: Keys.ambientShowArtwork) as? Bool ?? true
        ambientShowProgress = defaults.object(forKey: Keys.ambientShowProgress) as? Bool ?? false
        systemShowCPU = defaults.object(forKey: Keys.systemShowCPU) as? Bool ?? true
        systemShowRAM = defaults.object(forKey: Keys.systemShowRAM) as? Bool ?? true
        systemShowBattery = defaults.object(forKey: Keys.systemShowBattery) as? Bool ?? true
        systemShowNetwork = defaults.object(forKey: Keys.systemShowNetwork) as? Bool ?? true
        systemShowMicrophoneIndicator = defaults.object(forKey: Keys.systemShowMicrophoneIndicator) as? Bool ?? true
        systemShowAccessoryBattery = defaults.object(forKey: Keys.systemShowAccessoryBattery) as? Bool ?? true
        dropZoneAcceptFolders = defaults.object(forKey: Keys.dropZoneAcceptFolders) as? Bool ?? true
        appProfiles = defaults.codable([AppProfile].self, forKey: Keys.appProfiles) ?? []
    }

    private static let defaultLauncherApps: [String] = {
        let candidates = [
            "/Applications/Safari.app",
            "/System/Applications/Utilities/Terminal.app",
            "/System/Library/CoreServices/Finder.app",
        ]
        return candidates.filter { FileManager.default.fileExists(atPath: $0) }
    }()

    // MARK: — Themes

    /// Applique un thème nommé : couleur d'accent + opacité + rayon des coins en une fois.
    public func apply(_ theme: Theme) {
        hudUseSystemAccent = false
        hudAccentColorComponents = theme.accent
        panelOpacity = theme.panelOpacity
        cornerRadius = theme.cornerRadius
    }

    /// `id` du thème dont tous les réglages correspondent à l'état courant, sinon `nil`
    /// (couleur système active ou réglages personnalisés ne correspondant à aucun thème).
    public var activeThemeID: String? {
        guard !hudUseSystemAccent, hudAccentColorComponents.count >= 3 else { return nil }
        let tolerance = 0.005
        return Theme.all.first { theme in
            abs(hudAccentColorComponents[0] - theme.accent[0]) < tolerance &&
                abs(hudAccentColorComponents[1] - theme.accent[1]) < tolerance &&
                abs(hudAccentColorComponents[2] - theme.accent[2]) < tolerance &&
                abs(panelOpacity - theme.panelOpacity) < tolerance &&
                abs(cornerRadius - theme.cornerRadius) < tolerance
        }?.id
    }

    // MARK: — Module helpers

    public func isModuleEnabled(_ id: String) -> Bool {
        !disabledModuleIDs.contains(id)
    }

    public func setModule(_ id: String, enabled: Bool) {
        if enabled { disabledModuleIDs.remove(id) } else { disabledModuleIDs.insert(id) }
    }
}

// MARK: — UserDefaults keys

private enum Keys {
    static let collapseDelay = "collapseDelay"
    static let moduleOrder = "moduleOrder"
    static let disabledModules = "disabledModules"
    static let hudReplaceSystem = "hudReplaceSystem"
    static let hudBrightnessManualOnly = "hudBrightnessManualOnly"
    static let hudUseSystemAccent = "hudUseSystemAccent"
    static let hudAccentColorComponents = "hudAccentColorComponents"
    static let panelWidth = "panelWidth"
    static let cornerRadius = "cornerRadius"
    static let panelOpacity = "panelOpacity"
    static let notchDetectionMode = "notchDetectionMode"
    static let fullscreenBehavior = "fullscreenBehavior"
    static let showRingWhenTimerActive = "showRingWhenTimerActive"
    static let animationSpeed = "animationSpeed"
    static let clickBehavior = "clickBehavior"
    static let timerSoundEnabled = "timerSoundEnabled"
    static let timerAlertVisualOnly = "timerAlertVisualOnly"
    static let globalShortcutEnabled = "globalShortcutEnabled"
    static let shortcutOpenClose = "shortcutOpenClose"
    static let shortcutPaste = "shortcutPaste"
    static let shortcutNewTimer = "shortcutNewTimer"
    static let shortcutOpenMedia = "shortcutOpenMedia"
    static let showModuleLabels = "showModuleLabels"
    static let clipboardMaxItems = "clipboardMaxItems"
    static let clipboardPersistEnabled = "clipboardPersistEnabled"
    static let pomodoroWorkDuration = "pomodoroWorkDuration"
    static let pomodoroShortBreakDuration = "pomodoroShortBreakDuration"
    static let pomodoroLongBreakDuration = "pomodoroLongBreakDuration"
    static let targetScreenName = "targetScreenName"
    static let launcherApps = "launcherApps"
    static let ambientShowArtwork = "ambientShowArtwork"
    static let ambientShowProgress = "ambientShowProgress"
    static let systemShowCPU = "systemShowCPU"
    static let systemShowRAM = "systemShowRAM"
    static let systemShowBattery = "systemShowBattery"
    static let systemShowNetwork = "systemShowNetwork"
    static let systemShowMicrophoneIndicator = "systemShowMicrophoneIndicator"
    static let systemShowAccessoryBattery = "systemShowAccessoryBattery"
    static let dropZoneAcceptFolders = "dropZoneAcceptFolders"
    static let appProfiles = "appProfiles"
}

// MARK: — Helpers

private extension Double {
    var nonZero: Double? {
        self == 0 ? nil : self
    }
}

private extension UserDefaults {
    func shortcut(forKey key: String) -> GlobalKeyboardShortcut? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(GlobalKeyboardShortcut.self, from: data)
    }

    func setShortcut(_ shortcut: GlobalKeyboardShortcut, forKey key: String) {
        guard let data = try? JSONEncoder().encode(shortcut) else { return }
        set(data, forKey: key)
    }

    func setCodable<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        set(data, forKey: key)
    }

    func codable<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
