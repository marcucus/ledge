import SwiftUI
import Core

struct GeneralSettingsView: View {
    var store: SettingsStore

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { store.launchAtLogin },
                    set: { store.launchAtLogin = $0 }
                )) {
                    Text("settings.general.launchAtLogin")
                }
            }

            Section {
                collapseDelayRow
                peekDurationRow
            }

            Section {
                languageRow
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text("settings.section.general"))
    }

    private var collapseDelayRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("settings.general.collapseDelay")
            HStack {
                Slider(
                    value: Binding(
                        get: { store.collapseDelay },
                        set: { store.collapseDelay = $0 }
                    ),
                    in: 0.2...2.0,
                    step: 0.1
                )
                Text(String(format: "%.1f s", store.collapseDelay))
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
            }
        }
    }

    private var peekDurationRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("settings.general.peekDuration")
            HStack {
                Slider(
                    value: Binding(
                        get: { store.peekDuration },
                        set: { store.peekDuration = $0 }
                    ),
                    in: 0.5...5.0,
                    step: 0.5
                )
                Text(String(format: "%.1f s", store.peekDuration))
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
            }
        }
    }

    private var languageRow: some View {
        HStack {
            Text("settings.general.language")
            Spacer()
            Picker("", selection: .constant("system")) {
                Text("System").tag("system")
                Text("Français").tag("fr")
                Text("English").tag("en")
            }
            .labelsHidden()
            .frame(width: 160)
        }
    }
}
