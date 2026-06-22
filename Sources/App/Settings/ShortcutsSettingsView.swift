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
                shortcutRow(nameKey: "settings.shortcuts.openClose")
                shortcutRow(nameKey: "settings.shortcuts.paste")
                shortcutRow(nameKey: "settings.shortcuts.newTimer")
            }

            Section {
                Text("settings.shortcuts.comingSoon", bundle: localizationBundle)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text("settings.section.shortcuts", bundle: localizationBundle))
    }

    private func shortcutRow(nameKey: String) -> some View {
        HStack {
            Text(LocalizedStringKey(nameKey), bundle: localizationBundle)
            Spacer()
            Text("—")
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .opacity(store.globalShortcutEnabled ? 1 : 0.4)
    }
}
