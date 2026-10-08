import Carbon.HIToolbox
import Core
import Foundation

/// Gestionnaire de raccourcis globaux via Carbon RegisterEventHotKey.
/// Aucune permission supplémentaire requise (pas d'Input Monitoring).
/// Les combinaisons sont lues depuis `SettingsStore` — `refresh()` les ré-enregistre
/// après une modification dans les réglages.
final class GlobalShortcutManager {
    var onOpenClose: (() -> Void)?
    var onPaste: (() -> Void)?
    var onNewTimer: (() -> Void)?
    var onOpenMedia: (() -> Void)?

    private nonisolated(unsafe) static var shared: GlobalShortcutManager?
    private nonisolated(unsafe) static var handlerRef: EventHandlerRef?
    private nonisolated(unsafe) var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private let settings: SettingsStore
    private var isEnabled = false

    private enum HotKey: UInt32, CaseIterable {
        case openClose = 1
        case paste     = 2
        case newTimer  = 3
        case openMedia = 4

        var settingsID: String {
            switch self {
            case .openClose: "openClose"
            case .paste: "paste"
            case .newTimer: "newTimer"
            case .openMedia: "openMedia"
            }
        }

        func shortcut(in settings: SettingsStore) -> GlobalKeyboardShortcut {
            switch self {
            case .openClose: settings.shortcutOpenClose
            case .paste: settings.shortcutPaste
            case .newTimer: settings.shortcutNewTimer
            case .openMedia: settings.shortcutOpenMedia
            }
        }
    }

    init(settings: SettingsStore) {
        self.settings = settings
        GlobalShortcutManager.shared = self
        installEventHandler()
    }

    func enable() {
        isEnabled = true
        settings.clearGlobalShortcutConflicts()
        for id in HotKey.allCases { register(id, id.shortcut(in: settings)) }
    }

    func disable() {
        isEnabled = false
        for id in HotKey.allCases { unregister(id) }
        settings.clearGlobalShortcutConflicts()
    }

    /// Réconcilie l'état (activé + combinaisons) avec `SettingsStore` actuel — à appeler à
    /// chaque changement dans Réglages → Raccourcis.
    func applySettings() {
        guard settings.globalShortcutEnabled else {
            disable()
            return
        }
        if isEnabled { disable() }
        enable()
    }

    // MARK: — Private

    private func register(_ id: HotKey, _ shortcut: GlobalKeyboardShortcut) {
        guard hotKeyRefs[id.rawValue] == nil, shortcut.hasModifier else {
            settings.setGlobalShortcutConflict(id: id.settingsID, isConflicted: true)
            return
        }
        let hkID = EventHotKeyID(signature: 0x4C475348, id: id.rawValue)
        var ref: EventHotKeyRef?
        let err = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, hkID, GetApplicationEventTarget(), 0, &ref)
        if err == noErr, let ref {
            hotKeyRefs[id.rawValue] = ref
            settings.setGlobalShortcutConflict(id: id.settingsID, isConflicted: false)
        } else {
            settings.setGlobalShortcutConflict(id: id.settingsID, isConflicted: true)
        }
    }

    private func unregister(_ id: HotKey) {
        guard let ref = hotKeyRefs.removeValue(forKey: id.rawValue) else { return }
        UnregisterEventHotKey(ref)
    }

    private func installEventHandler() {
        guard GlobalShortcutManager.handlerRef == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                // Lire l'ID du hotkey depuis l'événement Carbon
                var hkID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                let id = hkID.id
                Task { @MainActor in GlobalShortcutManager.shared?.dispatch(id: id) }
                return noErr
            },
            1, &eventType, nil, &GlobalShortcutManager.handlerRef
        )
    }

    @MainActor private func dispatch(id: UInt32) {
        switch HotKey(rawValue: id) {
        case .openClose: onOpenClose?()
        case .paste:     onPaste?()
        case .newTimer:  onNewTimer?()
        case .openMedia: onOpenMedia?()
        case nil: break
        }
    }

    deinit {
        for ref in hotKeyRefs.values { UnregisterEventHotKey(ref) }
        GlobalShortcutManager.shared = nil
    }
}
