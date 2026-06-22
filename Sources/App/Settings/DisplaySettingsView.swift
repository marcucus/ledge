import AppKit
import Core
import SwiftUI

struct DisplaySettingsView: View {
    var store: SettingsStore
    @State private var screenNames: [String] = []

    var body: some View {
        Form {
            Section {
                Picker(selection: Binding(
                    get: { store.targetScreenName },
                    set: { store.targetScreenName = $0 }
                )) {
                    Text("settings.display.targetScreen.auto", bundle: localizationBundle).tag("")
                    ForEach(screenNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                } label: {
                    Text("settings.display.targetScreen", bundle: localizationBundle)
                }
            }

            Section {
                Picker(selection: Binding(
                    get: { store.fullscreenBehavior },
                    set: { store.fullscreenBehavior = $0 }
                )) {
                    Text("settings.display.fullscreen.accessible", bundle: localizationBundle)
                        .tag(FullscreenBehavior.accessible)
                    Text("settings.display.fullscreen.hidden", bundle: localizationBundle)
                        .tag(FullscreenBehavior.hidden)
                    Text("settings.display.fullscreen.overlay", bundle: localizationBundle)
                        .tag(FullscreenBehavior.overlay)
                } label: {
                    Text("settings.display.fullscreen", bundle: localizationBundle)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text("settings.section.display", bundle: localizationBundle))
        .task { screenNames = NSScreen.allNames }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
        ) { _ in screenNames = NSScreen.allNames }
    }
}
