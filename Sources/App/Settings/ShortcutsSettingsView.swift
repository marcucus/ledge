import SwiftUI
import Core

struct ShortcutsSettingsView: View {
    var store: SettingsStore

    private struct ShortcutRow: Identifiable {
        let id: String
        let labelKey: String
        let keys: String
    }

    private let shortcuts: [ShortcutRow] = [
        ShortcutRow(id: "openClose", labelKey: "settings.shortcuts.openClose", keys: "⌃ Space"),
        ShortcutRow(id: "media",     labelKey: "settings.shortcuts.media",     keys: "—"),
        ShortcutRow(id: "newTimer",  labelKey: "settings.shortcuts.newTimer",  keys: "⌥⌘ T"),
        ShortcutRow(id: "paste",     labelKey: "settings.shortcuts.paste",     keys: "⌥⌘ V"),
        ShortcutRow(id: "dropzone",  labelKey: "settings.shortcuts.dropzone",  keys: "—"),
    ]

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
                ForEach(shortcuts) { row in
                    HStack {
                        Text(LocalizedStringKey(row.labelKey), bundle: localizationBundle)
                        Spacer()
                        Text(row.keys)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text("settings.section.shortcuts", bundle: localizationBundle))
    }
}
