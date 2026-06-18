import Core
import SwiftUI

struct ShortcutsSettingsView: View {
    var store: SettingsStore

    var body: some View {
        Form {
            Section {
                Text("settings.shortcuts.comingSoon", bundle: localizationBundle)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text("settings.section.shortcuts", bundle: localizationBundle))
    }
}
