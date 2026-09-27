import Core
import SwiftUI

struct SettingsDetailView: View {
    var section: SettingsSection
    var store: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            detailHeader
            Divider().overlay(Color.white.opacity(0.08))
            detailContent
        }
        .background(Color(red: 0.063, green: 0.075, blue: 0.082))
    }

    private var detailHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(section.label, bundle: localizationBundle)
                    .font(.system(size: 20, weight: .semibold))
                Text("settings.detail.eyebrow", bundle: localizationBundle)
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1.8)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(height: 76)
        .background(Color.black.opacity(0.72))
    }

    @ViewBuilder
    private var detailContent: some View {
        switch section {
        case .general: GeneralSettingsView(store: store)
        case .appearance: AppearanceSettingsView(store: store)
        case .modules: ModulesSettingsView(store: store)
        case .appProfiles: AppProfilesSettingsView(store: store)
        case .display: DisplaySettingsView(store: store)
        case .permissions: PermissionsSettingsView()
        case .shortcuts: ShortcutsSettingsView(store: store)
        case .about: AboutSettingsView()
        }
    }
}
