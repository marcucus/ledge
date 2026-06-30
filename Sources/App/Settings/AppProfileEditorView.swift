import Core
import SwiftUI

/// Formulaire de création/édition d'un `AppProfile` : bundle ID cible + sélection des modules
/// activés pour cette app. L'ordre des modules suit `ModuleCatalog.entries` par défaut.
struct AppProfileEditorView: View {
    var store: SettingsStore
    let profile: AppProfile?

    @Environment(\.dismiss) private var dismiss
    @State private var bundleID: String = ""
    @State private var enabledModuleIDs: Set<String> = []

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(text: $bundleID) {
                        Text("settings.appProfiles.bundleID", bundle: localizationBundle)
                    }
                    .textFieldStyle(.roundedBorder)
                } header: {
                    Text("settings.appProfiles.bundleID", bundle: localizationBundle)
                }

                Section {
                    ForEach(ModuleCatalog.entries) { entry in
                        Toggle(isOn: moduleBinding(entry.id)) {
                            Text(LocalizedStringKey(entry.nameKey), bundle: localizationBundle)
                        }
                    }
                } header: {
                    Text("settings.appProfiles.modules", bundle: localizationBundle)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(Text("settings.appProfiles.title", bundle: localizationBundle))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("action.close", bundle: localizationBundle)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        Text("settings.appProfiles.save", bundle: localizationBundle)
                    }
                    .disabled(bundleID.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(minWidth: 360, minHeight: 320)
        .onAppear { loadProfile() }
    }

    private func moduleBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { enabledModuleIDs.contains(id) },
            set: { isOn in
                if isOn { enabledModuleIDs.insert(id) } else { enabledModuleIDs.remove(id) }
            }
        )
    }

    private func loadProfile() {
        guard let profile else {
            enabledModuleIDs = Set(ModuleCatalog.entries.map(\.id))
            return
        }
        bundleID = profile.bundleID
        enabledModuleIDs = Set(ModuleCatalog.entries.map(\.id)).subtracting(profile.disabledModuleIDs)
    }

    private func save() {
        let trimmedID = bundleID.trimmingCharacters(in: .whitespaces)
        guard !trimmedID.isEmpty else { return }
        let order = ModuleCatalog.entries.map(\.id)
        let disabled = Set(order).subtracting(enabledModuleIDs)
        let updated = AppProfile(
            id: profile?.id ?? UUID(),
            bundleID: trimmedID,
            moduleOrder: order,
            disabledModuleIDs: disabled
        )
        if let index = store.appProfiles.firstIndex(where: { $0.id == updated.id }) {
            store.appProfiles[index] = updated
        } else {
            store.appProfiles.append(updated)
        }
        dismiss()
    }
}
