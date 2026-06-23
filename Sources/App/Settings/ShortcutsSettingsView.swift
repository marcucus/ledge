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

    private func shortcutRow(nameKey: String, shortcut: String = "") -> some View {
        HStack {
            Text(LocalizedStringKey(nameKey), bundle: localizationBundle)
            Spacer()
            if shortcut.isEmpty {
                Text("—").foregroundStyle(.tertiary)
            } else {
                Text(shortcut)
                    .font(.system(.callout, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .opacity(store.globalShortcutEnabled ? 1 : 0.4)
    }
}
