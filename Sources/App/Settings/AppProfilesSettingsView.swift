import AppKit
import Core
import SwiftUI

/// Réglages des profils de visibilité des modules par application au premier plan.
/// Liste les `AppProfile` existants, permet d'en ajouter/éditer/supprimer.
struct AppProfilesSettingsView: View {
    var store: SettingsStore
    @State private var editingProfile: AppProfile?
    @State private var isPresentingNewProfile = false

    var body: some View {
        List {
            Section {
                if store.appProfiles.isEmpty {
                    Text("settings.appProfiles.empty", bundle: localizationBundle)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ForEach(store.appProfiles) { profile in
                        profileRow(profile)
                    }
                }
            } header: {
                Text("settings.appProfiles.list", bundle: localizationBundle)
            }
        }
        .navigationTitle(Text("settings.appProfiles.title", bundle: localizationBundle))
        .toolbar {
            ToolbarItem {
                Button {
                    isPresentingNewProfile = true
                } label: {
                    Label(LocalizedStringKey("settings.appProfiles.add"), systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingNewProfile) {
            AppProfileEditorView(store: store, profile: nil)
        }
        .sheet(item: $editingProfile) { profile in
            AppProfileEditorView(store: store, profile: profile)
        }
    }

    private func profileRow(_ profile: AppProfile) -> some View {
        HStack(spacing: 10) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName(for: profile.bundleID))
                    Text(profile.bundleID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "app.badge")
                    .frame(width: 20)
            }

            Spacer()

            Button {
                editingProfile = profile
            } label: {
                Image(systemName: "pencil")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                store.appProfiles.removeAll { $0.id == profile.id }
            } label: {
                Image(systemName: "trash")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func displayName(for bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
              let name = Bundle(url: url)?.infoDictionary?["CFBundleName"] as? String
        else { return bundleID }
        return name
    }
}
