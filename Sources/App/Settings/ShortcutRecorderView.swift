import Carbon.HIToolbox
import Core
import SwiftUI

/// Bouton qui capture la prochaine combinaison de touches pressée et la transmet à `onChange`.
/// Échap annule l'enregistrement sans modifier la valeur actuelle.
struct ShortcutRecorderView: View {
    let shortcut: GlobalKeyboardShortcut
    let onChange: (GlobalKeyboardShortcut) -> Void

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            isRecording ? stopRecording() : startRecording()
        } label: {
            Group {
                if isRecording {
                    Text("settings.shortcuts.recording", bundle: localizationBundle)
                } else {
                    Text(shortcut.displayString)
                }
            }
            .font(.system(.callout, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .frame(minWidth: 84)
            .background(isRecording ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyDown(event)
            return nil // consomme l'événement : n'atteint jamais le reste de l'UI
        }
    }

    private func stopRecording() {
        isRecording = false
        monitor.map(NSEvent.removeMonitor)
        monitor = nil
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard isRecording else { return }
        guard event.keyCode != UInt16(kVK_Escape) else { stopRecording(); return }
        let modifiers = carbonModifiers(from: event.modifierFlags)
        let candidate = GlobalKeyboardShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        guard candidate.hasModifier else { return } // ignore : exige au moins un modificateur
        onChange(candidate)
        stopRecording()
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }
}
