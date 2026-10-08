import Core
import SwiftUI

struct ShortcutsSettingsView: View {
    var store: SettingsStore

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { store.globalShortcutEnabled },
                    set: { store.globalShortcutEnabled = $0 }
                )) {
                    Text("settings.shortcuts.globalEnabled", bundle: localizationBundle)
                }
            }

            Section {
                shortcutRow(
                    id: "openClose",
                    nameKey: "settings.shortcuts.openClose",
                    shortcut: store.shortcutOpenClose,
                    onChange: { store.shortcutOpenClose = $0 }
                )
                shortcutRow(
                    id: "paste",
                    nameKey: "settings.shortcuts.paste",
                    shortcut: store.shortcutPaste,
                    onChange: { store.shortcutPaste = $0 }
                )
                shortcutRow(
                    id: "newTimer",
                    nameKey: "settings.shortcuts.newTimer",
                    shortcut: store.shortcutNewTimer,
                    onChange: { store.shortcutNewTimer = $0 }
                )
                shortcutRow(
                    id: "openMedia",
                    nameKey: "settings.shortcuts.openMedia",
                    shortcut: store.shortcutOpenMedia,
                    onChange: { store.shortcutOpenMedia = $0 }
                )
            } footer: {
                Text("settings.shortcuts.recorderHint", bundle: localizationBundle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func shortcutRow(
        id: String,
        nameKey: String,
        shortcut: GlobalKeyboardShortcut,
        onChange: @escaping (GlobalKeyboardShortcut) -> Void
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedStringKey(nameKey), bundle: localizationBundle)
                if store.globalShortcutConflictIDs.contains(id) {
                    Label {
                        Text("settings.shortcuts.conflict", bundle: localizationBundle)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }
            Spacer()
            ShortcutRecorderView(shortcut: shortcut, onChange: onChange)
        }
        .disabled(!store.globalShortcutEnabled)
        .opacity(store.globalShortcutEnabled ? 1 : 0.4)
    }
}
