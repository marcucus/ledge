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
                    Text("settings.display.fullscreen.accessible", bundle: localizationBundle).tag(FullscreenBehavior.accessible)
                    Text("settings.display.fullscreen.hidden", bundle: localizationBundle).tag(FullscreenBehavior.hidden)
                    Text("settings.display.fullscreen.overlay", bundle: localizationBundle).tag(FullscreenBehavior.overlay)
                } label: {
                    Text("settings.display.fullscreen", bundle: localizationBundle)
                }
            }

            Section {
                Picker(selection: Binding(
                    get: { store.notchDetectionMode },
                    set: { store.notchDetectionMode = $0 }
                )) {
                    Text("settings.display.notchDetection.automatic", bundle: localizationBundle).tag(NotchDetectionMode.automatic)
                    Text("settings.display.notchDetection.manual", bundle: localizationBundle).tag(NotchDetectionMode.manual)
                } label: {
                    Text("settings.display.notchDetection", bundle: localizationBundle)
                }
            }

            Section {
                Toggle(isOn: Binding(
                    get: { store.showRingWhenTimerActive },
                    set: { store.showRingWhenTimerActive = $0 }
                )) {
                    Text("settings.display.timerRing", bundle: localizationBundle)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text("settings.section.display", bundle: localizationBundle))
    }
}
