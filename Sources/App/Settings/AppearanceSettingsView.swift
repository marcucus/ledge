import Core
import SwiftUI

struct AppearanceSettingsView: View {
    var store: SettingsStore

    var body: some View {
        Form {
            Section {
                notchPreview
            }

            Section {
                panelWidthRow
            }

            Section {
                cornerRadiusRow
            }

            Section {
                Toggle(isOn: Binding(
                    get: { store.showModuleLabels },
                    set: { store.showModuleLabels = $0 }
                )) {
                    Text("settings.appearance.showModuleLabels", bundle: localizationBundle)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text("settings.section.appearance", bundle: localizationBundle))
    }

    // MARK: — Preview

    private var notchPreview: some View {
        let scale: CGFloat = 0.20
        let panelW: CGFloat = switch store.panelWidth {
        case .compact: 580
        case .standard: 744
        case .large: 920
        }

        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.06))
                .frame(maxWidth: .infinity)
                .frame(height: 72)

            NotchPanelShape(topEar: 12 * scale, bottomRadius: store.cornerRadius * scale)
                .fill(Color.black)
                .frame(width: panelW * scale, height: 48 * scale)
                .offset(y: -2)
        }
        .animation(.easeOut(duration: 0.2), value: store.cornerRadius)
        .animation(.easeOut(duration: 0.2), value: store.panelWidth)
    }

    // MARK: — Controls

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
