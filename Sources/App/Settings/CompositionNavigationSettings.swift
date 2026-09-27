import Core
import SwiftUI

struct CompositionNavigationSettings: View {
    var store: SettingsStore

    private var composition: PanelComposition { store.panelComposition }

    var body: some View {
        VStack(spacing: 0) {
            Toggle(isOn: gridVisibilityBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("settings.appearance.navigation.gridButton", bundle: localizationBundle)
                    Text("settings.appearance.navigation.gridButton.detail", bundle: localizationBundle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)

            Divider()

            ForEach(Array(ModulePlacement.allCases.enumerated()), id: \.element.rawValue) { index, placement in
                placementGroup(placement)
                if index < ModulePlacement.allCases.count - 1 {
                    Divider()
                }
            }
        }
    }

    private var gridVisibilityBinding: Binding<Bool> {
        Binding(
            get: { store.showsModuleGrid(in: composition) },
            set: { store.setShowsModuleGrid($0, in: composition) }
        )
    }

    private func placementGroup(_ placement: ModulePlacement) -> some View {
        let entries = entries(in: placement)
        return VStack(spacing: 0) {
            HStack {
                Text(titleKey(for: placement), bundle: localizationBundle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if placement != .hidden, !entries.isEmpty {
                    Text("settings.appearance.navigation.orderHint", bundle: localizationBundle)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 4)

            if entries.isEmpty {
                Text("settings.appearance.navigation.empty", bundle: localizationBundle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    modulePlacementRow(entry, index: index, count: entries.count, placement: placement)
                    if index < entries.count - 1 {
                        Divider().padding(.leading, 30)
                    }
                }
            }
        }
    }

    private func modulePlacementRow(
        _ entry: ModuleCatalog.Entry,
        index: Int,
        count: Int,
        placement: ModulePlacement
    ) -> some View {
        HStack(spacing: 12) {
            Label {
                Text(LocalizedStringKey(entry.nameKey), bundle: localizationBundle)
                    .lineLimit(1)
            } icon: {
                Image(systemName: entry.icon)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 18)
            }
            .frame(minWidth: 116, alignment: .leading)

            Spacer(minLength: 8)

            placementPicker(for: entry.id)
            reorderControls(for: entry.id, index: index, count: count, placement: placement)
        }
        .padding(.vertical, 7)
    }

    private func placementPicker(for moduleID: String) -> some View {
        Picker("", selection: placementBinding(for: moduleID)) {
            Text("settings.appearance.navigation.bar", bundle: localizationBundle)
                .tag(ModulePlacement.bar)
            Text("settings.appearance.navigation.grid", bundle: localizationBundle)
                .tag(ModulePlacement.grid)
            Text("settings.appearance.navigation.hidden", bundle: localizationBundle)
                .tag(ModulePlacement.hidden)
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .frame(width: 220)
    }

    @ViewBuilder
    private func reorderControls(
        for moduleID: String,
        index: Int,
        count: Int,
        placement: ModulePlacement
    ) -> some View {
        if placement != .hidden {
            reorderButton(
                icon: "chevron.up",
                label: "settings.appearance.navigation.moveEarlier",
                isDisabled: index == 0
            ) { store.moveModule(moduleID, by: -1, in: composition) }
            reorderButton(
                icon: "chevron.down",
                label: "settings.appearance.navigation.moveLater",
                isDisabled: index == count - 1
            ) { store.moveModule(moduleID, by: 1, in: composition) }
        } else {
            Color.clear.frame(width: 52, height: 24)
        }
    }

    private func reorderButton(
        icon: String,
        label: LocalizedStringKey,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.borderless)
        .disabled(isDisabled)
        .help(Text(label, bundle: localizationBundle))
        .accessibilityLabel(Text(label, bundle: localizationBundle))
    }

    private func entries(in placement: ModulePlacement) -> [ModuleCatalog.Entry] {
        let entriesByID = Dictionary(
            uniqueKeysWithValues: ModuleCatalog.entries
                .filter { $0.id != "system" }
                .map { ($0.id, $0) }
        )
        return store.moduleOrder(in: composition).compactMap { id in
            guard let entry = entriesByID[id], store.modulePlacement(id, in: composition) == placement else {
                return nil
            }
            return entry
        }
    }

    private func titleKey(for placement: ModulePlacement) -> LocalizedStringKey {
        switch placement {
        case .bar: "settings.appearance.navigation.bar"
        case .grid: "settings.appearance.navigation.grid"
        case .hidden: "settings.appearance.navigation.hidden"
        }
    }

    private func placementBinding(for moduleID: String) -> Binding<ModulePlacement> {
        Binding(
            get: { store.modulePlacement(moduleID, in: composition) },
            set: { store.setModulePlacement($0, for: moduleID, in: composition) }
        )
    }
}
