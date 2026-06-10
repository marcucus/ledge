import SwiftUI
import Core

struct SettingsDetailView: View {
    var section: SettingsSection
    var store: SettingsStore

    var body: some View {
        switch section {
        case .general:     GeneralSettingsView(store: store)
        case .appearance:  AppearanceSettingsView(store: store)
        case .modules:     ModulesSettingsView(store: store)
        case .display:     DisplaySettingsView(store: store)
        case .permissions: PermissionsSettingsView()
        case .shortcuts:   ShortcutsSettingsView(store: store)
        case .about:       AboutSettingsView()
        }
    }
}
