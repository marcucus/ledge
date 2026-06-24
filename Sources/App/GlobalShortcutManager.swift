import Carbon.HIToolbox
import Foundation

/// Gestionnaire de raccourcis globaux via Carbon RegisterEventHotKey.
/// Aucune permission supplémentaire requise (pas d'Input Monitoring).
final class GlobalShortcutManager {
    var onOpenClose: (() -> Void)?
    var onPaste: (() -> Void)?
    var onNewTimer: (() -> Void)?
    var onOpenMedia: (() -> Void)?

    private nonisolated(unsafe) static var shared: GlobalShortcutManager?
    private nonisolated(unsafe) static var handlerRef: EventHandlerRef?
    private nonisolated(unsafe) var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]

    private enum HK: UInt32 {
        case openClose = 1
        case paste     = 2
        case newTimer  = 3
        case openMedia = 4
    }

    init() {
        GlobalShortcutManager.shared = self
        installEventHandler()
    }

    func enable() {
        register(.openClose, keyCode: UInt32(kVK_Space),    modifiers: UInt32(optionKey))
        register(.paste,     keyCode: UInt32(kVK_ANSI_V),   modifiers: UInt32(optionKey))
        register(.newTimer,  keyCode: UInt32(kVK_ANSI_T),   modifiers: UInt32(optionKey))
        register(.openMedia, keyCode: UInt32(kVK_ANSI_M),   modifiers: UInt32(optionKey))
    }

    func disable() {
        for id in [HK.openClose, .paste, .newTimer, .openMedia] { unregister(id) }
    }

    // MARK: — Private

    private func register(_ id: HK, keyCode: UInt32, modifiers: UInt32) {
        guard hotKeyRefs[id.rawValue] == nil else { return }
        let hkID = EventHotKeyID(signature: 0x4C475348, id: id.rawValue)
        var ref: EventHotKeyRef?
        let err = RegisterEventHotKey(keyCode, modifiers, hkID, GetApplicationEventTarget(), 0, &ref)
        if err == noErr, let ref { hotKeyRefs[id.rawValue] = ref }
    }

    private func unregister(_ id: HK) {
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
        switch HK(rawValue: id) {
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
