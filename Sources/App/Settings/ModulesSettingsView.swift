import Core
import SwiftUI

struct ModulesSettingsView: View {
    var store: SettingsStore

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
    }

    /// Entrées dans l'ordre persisté, en rattachant à la fin tout module absent de l'ordre (robustesse).
    private var orderedEntries: [ModuleCatalog.Entry] {
        let ordered = store.moduleOrder.compactMap(ModuleCatalog.entry(for:))
        let missing = ModuleCatalog.entries.filter { entry in !ordered.contains { $0.id == entry.id } }
        return ordered + missing
    }

    private func moduleRow(_ entry: ModuleCatalog.Entry) -> some View {
        HStack {
            Label {
                Text(LocalizedStringKey(entry.nameKey), bundle: localizationBundle)
            } icon: {
                Image(systemName: entry.icon)
            }
            Spacer()
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
