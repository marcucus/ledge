import SwiftUI
import Core

struct ModulesSettingsView: View {
    var store: SettingsStore

    var body: some View {
        Form {
            Section {
                moduleRow(
                    icon: "music.note",
                    nameKey: "module.media.label",
                    enabled: Binding(
                        get: { store.mediaEnabled },
                        set: { store.mediaEnabled = $0 }
                    )
                )
                moduleRow(
                    icon: "timer",
                    nameKey: "module.timers.label",
                    enabled: Binding(
                        get: { store.timersEnabled },
                        set: { store.timersEnabled = $0 }
                    )
                )
                moduleRow(
                    icon: "doc.on.clipboard",
                    nameKey: "module.clipboard.label",
                    enabled: Binding(
                        get: { store.clipboardEnabled },
                        set: { store.clipboardEnabled = $0 }
                    )
                )
                moduleRow(
                    icon: "cpu",
                    nameKey: "module.system.label",
                    enabled: Binding(
                        get: { store.systemEnabled },
                        set: { store.systemEnabled = $0 }
                    )
                )
                moduleRow(
                    icon: "arrow.down.to.line",
                    nameKey: "module.dropzone.label",
                    enabled: Binding(
                        get: { store.dropzoneEnabled },
                        set: { store.dropzoneEnabled = $0 }
                    )
                )
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text("settings.section.modules"))
    }

    private func moduleRow(
        icon: String,
        nameKey: LocalizedStringKey,
        enabled: Binding<Bool>
    ) -> some View {
        HStack {
            Label(nameKey, systemImage: icon)
            Spacer()
            Toggle(isOn: enabled) {
                Text("settings.modules.enabled")
            }
            .labelsHidden()
        }
    }
}
