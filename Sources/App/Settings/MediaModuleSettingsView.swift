import Core
import SwiftUI

struct MediaModuleSettingsView: View {
    var store: SettingsStore

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { store.ambientShowArtwork },
                    set: { store.ambientShowArtwork = $0 }
                )) {
                    Text("settings.modules.media.ambientArtwork", bundle: localizationBundle)
                }
                Toggle(isOn: Binding(
                    get: { store.ambientShowProgress },
                    set: { store.ambientShowProgress = $0 }
                )) {
                    Text("settings.modules.media.ambientProgress", bundle: localizationBundle)
                }
            } header: {
                Text("settings.modules.media.ambient", bundle: localizationBundle)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text("module.media.label", bundle: localizationBundle))
    }
}
