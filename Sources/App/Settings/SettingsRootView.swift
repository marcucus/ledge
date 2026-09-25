import Core
import SwiftUI

struct SettingsRootView: View {
    var store: SettingsStore
    @State private var selection: SettingsSection?
    @AppStorage("preferredLanguage") private var language: String = "system"

    init(store: SettingsStore, initialSelection: SettingsSection = .general) {
        self.store = store
        _selection = State(initialValue: initialSelection)
    }

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
