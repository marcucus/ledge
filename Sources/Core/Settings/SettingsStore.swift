import Foundation

@Observable public final class SettingsStore {
    public static let shared = SettingsStore()

    private let defaults = UserDefaults.standard

    /// Ordre d'affichage des onglets (= ordre des modules dans l'encoche). Persisté, observable.
    public var moduleOrder: [String] {
        didSet { defaults.set(moduleOrder, forKey: Keys.moduleOrder) }
    }

    /// Modules désactivés par l'utilisateur (par défaut tous activés). Persisté, observable.
    private var disabledModuleIDs: Set<String> {
        didSet { defaults.set(Array(disabledModuleIDs), forKey: Keys.disabledModules) }
    }

    public static let defaultModuleOrder = ["media", "timers", "dropzone", "clipboard", "system"]

    private init() {
        moduleOrder = (defaults.array(forKey: Keys.moduleOrder) as? [String]) ?? Self.defaultModuleOrder
        disabledModuleIDs = Set(defaults.stringArray(forKey: Keys.disabledModules) ?? [])
    }

    // MARK: — General

    public var collapseDelay: Double {
        get { defaults.double(forKey: Keys.collapseDelay).nonZero ?? 0.6 }
        set { defaults.set(newValue, forKey: Keys.collapseDelay) }
    }

    public var launchAtLogin: Bool {
        get { defaults.bool(forKey: Keys.launchAtLogin) }
        set { defaults.set(newValue, forKey: Keys.launchAtLogin) }
    }

    public var peekDuration: Double {
        get { defaults.double(forKey: Keys.peekDuration).nonZero ?? 2.0 }
        set { defaults.set(newValue, forKey: Keys.peekDuration) }
    }

    // MARK: — Modules

    public func isModuleEnabled(_ id: String) -> Bool {
        !disabledModuleIDs.contains(id)
    }

    public func setModule(_ id: String, enabled: Bool) {
        if enabled { disabledModuleIDs.remove(id) } else { disabledModuleIDs.insert(id) }
    }

    // MARK: — System HUD

    /// Remplace le HUD volume/luminosité natif de macOS par celui de Ledge. Activé par défaut.
    public var hudReplaceSystem: Bool {
        get { defaults.object(forKey: Keys.hudReplaceSystem) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.hudReplaceSystem) }
    }

    // MARK: — Appearance

    public var panelWidth: PanelWidth {
        get { PanelWidth(rawValue: defaults.integer(forKey: Keys.panelWidth)) ?? .standard }
        set { defaults.set(newValue.rawValue, forKey: Keys.panelWidth) }
    }

    // MARK: — Display

    public var notchDetectionMode: NotchDetectionMode {
        get { NotchDetectionMode(rawValue: defaults.integer(forKey: Keys.notchDetectionMode)) ?? .automatic }
        set { defaults.set(newValue.rawValue, forKey: Keys.notchDetectionMode) }
    }

    public var fullscreenBehavior: FullscreenBehavior {
        get { FullscreenBehavior(rawValue: defaults.integer(forKey: Keys.fullscreenBehavior)) ?? .accessible }
        set { defaults.set(newValue.rawValue, forKey: Keys.fullscreenBehavior) }
    }

    public var showRingWhenTimerActive: Bool {
        get { defaults.object(forKey: Keys.showRingWhenTimerActive) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.showRingWhenTimerActive) }
    }

    // MARK: — Shortcuts

    public var globalShortcutEnabled: Bool {
        get { defaults.object(forKey: Keys.globalShortcutEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.globalShortcutEnabled) }
    }
}

// MARK: — UserDefaults keys

private enum Keys {
    static let collapseDelay = "collapseDelay"
    static let launchAtLogin = "launchAtLogin"
    static let peekDuration = "peekDuration"
    static let moduleOrder = "moduleOrder"
    static let disabledModules = "disabledModules"
    static let hudReplaceSystem = "hudReplaceSystem"
    static let panelWidth = "panelWidth"
    static let notchDetectionMode = "notchDetectionMode"
    static let fullscreenBehavior = "fullscreenBehavior"
    static let showRingWhenTimerActive = "showRingWhenTimerActive"
    static let globalShortcutEnabled = "globalShortcutEnabled"
}

// MARK: — Helpers

private extension Double {
    var nonZero: Double? {
        self == 0 ? nil : self
    }
}
