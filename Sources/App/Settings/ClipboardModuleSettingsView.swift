import Core
import SwiftUI

struct ClipboardModuleSettingsView: View {
    var store: SettingsStore

    var body: some View {
        Form {
            Section {
                Picker(selection: Binding(
                    get: { store.clipboardMaxItems },
                    set: { store.clipboardMaxItems = $0 }
                )) {
                    Text("settings.modules.clipboard.maxItems.25", bundle: localizationBundle).tag(25)
                    Text("settings.modules.clipboard.maxItems.50", bundle: localizationBundle).tag(50)
                    Text("settings.modules.clipboard.maxItems.100", bundle: localizationBundle).tag(100)
                    Text("settings.modules.clipboard.maxItems.unlimited", bundle: localizationBundle).tag(0)
                } label: {
                    Text("settings.modules.clipboard.maxItems", bundle: localizationBundle)
                }
            }

            Section {
                Toggle(isOn: Binding(
                    get: { store.clipboardPersistEnabled },
                    set: { store.clipboardPersistEnabled = $0 }
                )) {
                    Text("settings.modules.clipboard.persist", bundle: localizationBundle)
                }
            } footer: {
                Text("settings.modules.clipboard.persist.hint", bundle: localizationBundle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text("module.clipboard.label", bundle: localizationBundle))
    }
}
