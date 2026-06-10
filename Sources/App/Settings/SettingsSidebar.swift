import SwiftUI

struct SettingsSidebar: View {
    @Binding var selection: SettingsSection?

    var body: some View {
        List(SettingsSection.allCases, selection: $selection) { section in
            Label(section.label, systemImage: section.icon)
                .tag(section)
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
    }
}
