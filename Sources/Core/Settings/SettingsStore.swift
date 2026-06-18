import Foundation

@Observable public final class SettingsStore {
    public static let shared = SettingsStore()

    private let defaults = UserDefaults.standard

    public static let defaultModuleOrder = ["media", "timers", "dropzone", "clipboard", "system"]

    // MARK: — General

    public var collapseDelay: Double {
        didSet { defaults.set(collapseDelay, forKey: Keys.collapseDelay) }
    }

    public var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
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

    // MARK: — Appearance

    public var panelWidth: PanelWidth {
        didSet { defaults.set(panelWidth.rawValue, forKey: Keys.panelWidth) }
    }

    public var cornerRadius: Double {
        didSet { defaults.set(cornerRadius, forKey: Keys.cornerRadius) }
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

    // MARK: — Shortcuts

    public var globalShortcutEnabled: Bool {
        didSet { defaults.set(globalShortcutEnabled, forKey: Keys.globalShortcutEnabled) }
    }

    private init() {
        collapseDelay = defaults.double(forKey: Keys.collapseDelay).nonZero ?? 0.6
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        moduleOrder = (defaults.array(forKey: Keys.moduleOrder) as? [String]) ?? Self.defaultModuleOrder
        disabledModuleIDs = Set(defaults.stringArray(forKey: Keys.disabledModules) ?? [])
        hudReplaceSystem = defaults.object(forKey: Keys.hudReplaceSystem) as? Bool ?? true
        panelWidth = PanelWidth(rawValue: defaults.integer(forKey: Keys.panelWidth)) ?? .standard
        cornerRadius = defaults.double(forKey: Keys.cornerRadius).nonZero ?? 12.0
        notchDetectionMode = NotchDetectionMode(rawValue: defaults.integer(forKey: Keys.notchDetectionMode)) ?? .automatic
        fullscreenBehavior = FullscreenBehavior(rawValue: defaults.integer(forKey: Keys.fullscreenBehavior)) ?? .accessible
        showRingWhenTimerActive = defaults.object(forKey: Keys.showRingWhenTimerActive) as? Bool ?? true
        globalShortcutEnabled = defaults.object(forKey: Keys.globalShortcutEnabled) as? Bool ?? true
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
    static let launchAtLogin = "launchAtLogin"
    static let moduleOrder = "moduleOrder"
    static let disabledModules = "disabledModules"
    static let hudReplaceSystem = "hudReplaceSystem"
    static let panelWidth = "panelWidth"
    static let cornerRadius = "cornerRadius"
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
