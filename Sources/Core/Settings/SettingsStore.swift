import Foundation
import SwiftUI

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

    // MARK: — NavBar

    public var showModuleLabels: Bool {
        didSet { defaults.set(showModuleLabels, forKey: Keys.showModuleLabels) }
    }

    // MARK: — Clipboard module

    public var clipboardMaxItems: Int {
        didSet { defaults.set(clipboardMaxItems, forKey: Keys.clipboardMaxItems) }
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

    // MARK: — DropZone

    public var dropZoneAcceptFolders: Bool {
        didSet { defaults.set(dropZoneAcceptFolders, forKey: Keys.dropZoneAcceptFolders) }
    }

    private init() {
        collapseDelay = defaults.double(forKey: Keys.collapseDelay).nonZero ?? 0.6
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
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
        showRingWhenTimerActive = defaults.object(forKey: Keys.showRingWhenTimerActive) as? Bool ?? true
        animationSpeed = AnimationSpeed(rawValue: defaults.object(forKey: Keys.animationSpeed) as? Int ?? -1) ?? .normal
        clickBehavior = ClickBehavior(rawValue: defaults.object(forKey: Keys.clickBehavior) as? Int ?? -1) ?? .expand
        timerSoundEnabled = defaults.object(forKey: Keys.timerSoundEnabled) as? Bool ?? true
        timerAlertVisualOnly = defaults.object(forKey: Keys.timerAlertVisualOnly) as? Bool ?? false
        globalShortcutEnabled = defaults.object(forKey: Keys.globalShortcutEnabled) as? Bool ?? true
        showModuleLabels = defaults.object(forKey: Keys.showModuleLabels) as? Bool ?? false
        clipboardMaxItems = defaults.object(forKey: Keys.clipboardMaxItems) as? Int ?? 50
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
        dropZoneAcceptFolders = defaults.object(forKey: Keys.dropZoneAcceptFolders) as? Bool ?? true
    }

    private static let defaultLauncherApps: [String] = {
        let candidates = [
            "/Applications/Safari.app",
            "/System/Applications/Utilities/Terminal.app",
            "/System/Library/CoreServices/Finder.app",
        ]
        return candidates.filter { FileManager.default.fileExists(atPath: $0) }
    }()

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
    static let showModuleLabels = "showModuleLabels"
    static let clipboardMaxItems = "clipboardMaxItems"
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
    static let dropZoneAcceptFolders = "dropZoneAcceptFolders"
}

// MARK: — Helpers

private extension Double {
    var nonZero: Double? {
        self == 0 ? nil : self
    }
}
