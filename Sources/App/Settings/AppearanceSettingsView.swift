import Core
import SwiftUI

struct AppearanceSettingsView: View {
    var store: SettingsStore

    var body: some View {
        Form {
            Section {
                panelWidthRow
            }

            Section {
                cornerRadiusRow
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text("settings.section.appearance", bundle: localizationBundle))
    }

    private var panelWidthRow: some View {
        Picker(selection: Binding(
            get: { store.panelWidth },
            set: { store.panelWidth = $0 }
        )) {
            Text("settings.appearance.panelWidth.compact", bundle: localizationBundle).tag(PanelWidth.compact)
            Text("settings.appearance.panelWidth.standard", bundle: localizationBundle).tag(PanelWidth.standard)
            Text("settings.appearance.panelWidth.large", bundle: localizationBundle).tag(PanelWidth.large)
        } label: {
            Text("settings.appearance.panelWidth", bundle: localizationBundle)
        }
        .pickerStyle(.segmented)
    }

    private var cornerRadiusRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("settings.appearance.cornerRadius", bundle: localizationBundle)
            HStack {
                Slider(value: Binding(
                    get: { store.cornerRadius },
                    set: { store.cornerRadius = $0 }
                ), in: 4...24, step: 1)
                Text(String(format: "%.0f pt", store.cornerRadius))
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
            }
        }
    }
}
