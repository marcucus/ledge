import Core
import SwiftUI

struct ModulesSettingsView: View {
    var store: SettingsStore
    @State private var selectedEntryForSettings: ModuleCatalog.Entry?

    var body: some View {
        List {
            Section {
                ForEach(orderedEntries) { entry in
                    moduleRow(entry)
                }
                .onMove(perform: move)
            }
        }
        .navigationTitle(Text("settings.section.modules", bundle: localizationBundle))
        .sheet(item: $selectedEntryForSettings) { entry in
            if let builder = entry.settingsBuilder {
                NavigationStack {
                    builder(store)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button {
                                    selectedEntryForSettings = nil
                                } label: {
                                    Text("action.close", bundle: localizationBundle)
                                }
                            }
                        }
                }
                .frame(minWidth: 360, minHeight: 260)
            }
        }
    }

    private var orderedEntries: [ModuleCatalog.Entry] {
        let ordered = store.moduleOrder.compactMap(ModuleCatalog.entry(for:))
        let missing = ModuleCatalog.entries.filter { entry in !ordered.contains { $0.id == entry.id } }
        return ordered + missing
    }

    private func moduleRow(_ entry: ModuleCatalog.Entry) -> some View {
        HStack(spacing: 10) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(entry.nameKey), bundle: localizationBundle)
                    Text(LocalizedStringKey(entry.descriptionKey), bundle: localizationBundle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: entry.icon)
                    .frame(width: 20)
            }

            Spacer()

            if entry.settingsBuilder != nil {
                Button {
                    selectedEntryForSettings = entry
                } label: {
                    Image(systemName: "gearshape")
                        .imageScale(.small)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(Text("settings.modules.settings", bundle: localizationBundle))
            }

            Toggle(isOn: Binding(
                get: { store.isModuleEnabled(entry.id) },
                set: { store.setModule(entry.id, enabled: $0) }
            )) { EmptyView() }
                .labelsHidden()
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var order = orderedEntries.map(\.id)
        order.move(fromOffsets: source, toOffset: destination)
        store.moduleOrder = order
    }
}
