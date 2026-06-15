import SwiftUI
import Core

struct SettingsRootView: View {
    var store: SettingsStore
    @State private var selection: SettingsSection? = .general
    @AppStorage("preferredLanguage") private var language: String = "system"

    var body: some View {
        NavigationSplitView {
            SettingsSidebar(selection: $selection)
        } detail: {
            SettingsDetailView(section: selection ?? .general, store: store)
        }
        .frame(minWidth: 620, minHeight: 440)
        .id(language)
    }
}
