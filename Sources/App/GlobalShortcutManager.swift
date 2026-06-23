import Carbon.HIToolbox
import Foundation

/// Raccourci clavier global via Carbon RegisterEventHotKey.
/// Aucune permission supplémentaire requise (pas d'Input Monitoring).
final class GlobalShortcutManager {
    var onActivated: (() -> Void)?

    // Accès depuis le callback C et deinit (nonisolés)
    private nonisolated(unsafe) static var shared: GlobalShortcutManager?
    private nonisolated(unsafe) var hotKeyRef: EventHotKeyRef?
    private nonisolated(unsafe) var handlerRef: EventHandlerRef?

    init() {
        GlobalShortcutManager.shared = self
        installEventHandler()
    }

    /// Active le raccourci (⌥ Space par défaut). Doit être appelé sur le main thread.
    func enable(keyCode: UInt32 = UInt32(kVK_Space), modifiers: UInt32 = UInt32(optionKey)) {
        guard hotKeyRef == nil else { return }
        let id = EventHotKeyID(signature: 0x4C475348, id: 1) // 'LGSH'
        let err = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        if err != noErr { hotKeyRef = nil }
    }

    func disable() {
        guard let ref = hotKeyRef else { return }
        UnregisterEventHotKey(ref)
        hotKeyRef = nil
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ -> OSStatus in
                Task { @MainActor in GlobalShortcutManager.shared?.onActivated?() }
                return noErr
            },
            1, &eventType, nil, &handlerRef
        )
    }

    deinit {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        if let ref = handlerRef { RemoveEventHandler(ref) }
        GlobalShortcutManager.shared = nil
    }
}
