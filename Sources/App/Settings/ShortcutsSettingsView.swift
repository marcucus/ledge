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
                    nameKey: "settings.shortcuts.openClose",
                    shortcut: store.shortcutOpenClose,
                    onChange: { store.shortcutOpenClose = $0 }
                )
                shortcutRow(
                    nameKey: "settings.shortcuts.paste",
                    shortcut: store.shortcutPaste,
                    onChange: { store.shortcutPaste = $0 }
                )
                shortcutRow(
                    nameKey: "settings.shortcuts.newTimer",
                    shortcut: store.shortcutNewTimer,
                    onChange: { store.shortcutNewTimer = $0 }
                )
                shortcutRow(
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
        .navigationTitle(Text("settings.section.shortcuts", bundle: localizationBundle))
    }

    private func shortcutRow(
        nameKey: String,
        shortcut: GlobalKeyboardShortcut,
        onChange: @escaping (GlobalKeyboardShortcut) -> Void
    ) -> some View {
        HStack {
            Text(LocalizedStringKey(nameKey), bundle: localizationBundle)
            Spacer()
            ShortcutRecorderView(shortcut: shortcut, onChange: onChange)
        }
        .disabled(!store.globalShortcutEnabled)
        .opacity(store.globalShortcutEnabled ? 1 : 0.4)
    }
}
