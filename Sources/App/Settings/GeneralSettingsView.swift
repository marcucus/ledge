import Core
import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View {
    var store: SettingsStore
    @AppStorage("preferredLanguage") private var preferredLanguage: String = "system"

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { SMAppService.mainApp.status == .enabled },
                    set: { shouldEnable in
                        if shouldEnable {
                            try? SMAppService.mainApp.register()
                        } else {
                            try? SMAppService.mainApp.unregister()
                        }
                    }
                )) {
                    Text("settings.general.launchAtLogin", bundle: localizationBundle)
                }
            }

            Section {
                Toggle(isOn: Binding(
                    get: { store.hudReplaceSystem },
                    set: { store.hudReplaceSystem = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("settings.general.hudReplace", bundle: localizationBundle)
                        Text("settings.general.hudReplaceDetail", bundle: localizationBundle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if store.hudReplaceSystem {
                    Toggle(isOn: Binding(
                        get: { store.hudBrightnessManualOnly },
                        set: { store.hudBrightnessManualOnly = $0 }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("settings.general.hudBrightnessManualOnly", bundle: localizationBundle)
                            Text("settings.general.hudBrightnessManualOnlyDetail", bundle: localizationBundle)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                collapseDelayRow
            }

            Section {
                clickBehaviorRow
            }

            Section {
                languageRow
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text("settings.section.general", bundle: localizationBundle))
    }

    private var collapseDelayRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("settings.general.collapseDelay", bundle: localizationBundle)
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

    private var clickBehaviorRow: some View {
        Picker(selection: Binding(
            get: { store.clickBehavior },
            set: { store.clickBehavior = $0 }
        )) {
            Text("settings.general.clickBehavior.expand", bundle: localizationBundle).tag(ClickBehavior.expand)
            Text("settings.general.clickBehavior.peek", bundle: localizationBundle).tag(ClickBehavior.peek)
        } label: {
            Text("settings.general.clickBehavior", bundle: localizationBundle)
        }
        .pickerStyle(.segmented)
    }

    private var languageRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("settings.general.language", bundle: localizationBundle)
                Spacer()
                Picker("", selection: $preferredLanguage) {
                    Text("System").tag("system")
                    Text("Français").tag("fr")
                    Text("English").tag("en")
                }
                .labelsHidden()
                .frame(width: 160)
                .onChange(of: preferredLanguage) { _, newValue in
                    if newValue == "system" {
                        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                    } else {
                        UserDefaults.standard.set([newValue], forKey: "AppleLanguages")
                    }
                }
            }
            Text("settings.general.languageRestart", bundle: localizationBundle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
