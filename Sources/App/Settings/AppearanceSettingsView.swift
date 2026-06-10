import SwiftUI
import Core

struct AppearanceSettingsView: View {
    var store: SettingsStore
    @State private var cornerRadius: Double = 12.0

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
        .navigationTitle(Text("settings.section.appearance"))
    }

    private var panelWidthRow: some View {
        Picker(selection: Binding(
            get: { store.panelWidth },
            set: { store.panelWidth = $0 }
        )) {
            Text("Compact").tag(PanelWidth.compact)
            Text("Standard").tag(PanelWidth.standard)
            Text("Large").tag(PanelWidth.large)
        } label: {
            Text("settings.appearance.panelWidth")
        }
        .pickerStyle(.segmented)
    }

    private var cornerRadiusRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("settings.appearance.cornerRadius")
            HStack {
                Slider(value: $cornerRadius, in: 4...24, step: 1)
                Text(String(format: "%.0f pt", cornerRadius))
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
            }
        }
    }
}
