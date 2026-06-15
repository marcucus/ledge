import SwiftUI
import Core

struct SettingsSidebar: View {
    @Binding var selection: SettingsSection?

    var body: some View {
        List(SettingsSection.allCases, selection: $selection) { section in
            Label {
                Text(section.label, bundle: localizationBundle)
            } icon: {
                Image(systemName: section.icon)
            }
            .tag(section)
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
    }
}
