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
                shortcutRow(nameKey: "settings.shortcuts.openClose", shortcut: "⌥ Space")
                shortcutRow(nameKey: "settings.shortcuts.paste",     shortcut: "⌥ V")
                shortcutRow(nameKey: "settings.shortcuts.newTimer",  shortcut: "⌥ T")
                shortcutRow(nameKey: "settings.shortcuts.openMedia", shortcut: "⌥ M")
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text("settings.section.shortcuts", bundle: localizationBundle))
    }

    private func shortcutRow(nameKey: String, shortcut: String) -> some View {
        HStack {
            Text(LocalizedStringKey(nameKey), bundle: localizationBundle)
            Spacer()
            Text(shortcut)
                .font(.system(.callout, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .opacity(store.globalShortcutEnabled ? 1 : 0.4)
    }
}
