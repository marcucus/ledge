import SwiftUI
import Core

struct DisplaySettingsView: View {
    var store: SettingsStore

    var body: some View {
        Form {
            Section {
                Picker(selection: Binding(
                    get: { store.fullscreenBehavior },
                    set: { store.fullscreenBehavior = $0 }
                )) {
                    Text("settings.display.fullscreen.accessible").tag(FullscreenBehavior.accessible)
                    Text("settings.display.fullscreen.hidden").tag(FullscreenBehavior.hidden)
                    Text("settings.display.fullscreen.overlay").tag(FullscreenBehavior.overlay)
                } label: {
                    Text("settings.display.fullscreen")
                }
            }

            Section {
                Picker(selection: Binding(
                    get: { store.notchDetectionMode },
                    set: { store.notchDetectionMode = $0 }
                )) {
                    Text("settings.display.notchDetection.automatic").tag(NotchDetectionMode.automatic)
                    Text("settings.display.notchDetection.manual").tag(NotchDetectionMode.manual)
                } label: {
                    Text("settings.display.notchDetection")
                }
            }

            Section {
                Toggle(isOn: Binding(
                    get: { store.showRingWhenTimerActive },
                    set: { store.showRingWhenTimerActive = $0 }
                )) {
                    Text("settings.display.timerRing")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text("settings.section.display"))
    }
}
