import Core
import SwiftUI

struct DropZoneModuleSettingsView: View {
    var store: SettingsStore

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { store.dropZoneAcceptFolders },
                    set: { store.dropZoneAcceptFolders = $0 }
                )) {
                    Text("settings.modules.dropzone.acceptFolders", bundle: localizationBundle)
                }
            } header: {
                Text("settings.modules.dropzone.files", bundle: localizationBundle)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text("module.dropzone.label", bundle: localizationBundle))
    }
}
