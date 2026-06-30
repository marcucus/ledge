import AppKit
import Core
import SwiftUI

struct SystemModuleSettingsView: View {
    var store: SettingsStore
    @State private var paths: [String] = []

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(get: { store.systemShowCPU }, set: { store.systemShowCPU = $0 })) {
                    Text("settings.modules.system.showCPU", bundle: localizationBundle)
                }
                Toggle(isOn: Binding(get: { store.systemShowRAM }, set: { store.systemShowRAM = $0 })) {
                    Text("settings.modules.system.showRAM", bundle: localizationBundle)
                }
                Toggle(isOn: Binding(get: { store.systemShowBattery }, set: { store.systemShowBattery = $0 })) {
                    Text("settings.modules.system.showBattery", bundle: localizationBundle)
                }
                Toggle(isOn: Binding(get: { store.systemShowNetwork }, set: { store.systemShowNetwork = $0 })) {
                    Text("settings.modules.system.showNetwork", bundle: localizationBundle)
                }
                Toggle(
                    isOn: Binding(
                        get: { store.systemShowMicrophoneIndicator },
                        set: { store.systemShowMicrophoneIndicator = $0 }
                    )
                ) {
                    Text("settings.modules.system.showMicrophoneIndicator", bundle: localizationBundle)
                }
                Toggle(
                    isOn: Binding(
                        get: { store.systemShowAccessoryBattery },
                        set: { store.systemShowAccessoryBattery = $0 }
                    )
                ) {
                    Text("settings.modules.system.showAccessoryBattery", bundle: localizationBundle)
                }
            } header: {
                Text("settings.modules.system.gauges", bundle: localizationBundle)
            }

            Section {
                if paths.isEmpty {
                    Text("settings.modules.system.launcher.empty", bundle: localizationBundle)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ForEach(paths, id: \.self) { path in
                        appRow(path: path)
                    }
                    .onDelete { offsets in
                        paths.remove(atOffsets: offsets)
                        store.launcherApps = paths
                    }
                    .onMove { from, to in
                        paths.move(fromOffsets: from, toOffset: to)
                        store.launcherApps = paths
                    }
                }

                Button {
                    pickApps()
                } label: {
                    Label(
                        LocalizedStringKey("settings.modules.system.launcher.add"),
                        systemImage: "plus"
                    )
                }
            } header: {
                Text("system.section.launcher", bundle: localizationBundle)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text("module.system.label", bundle: localizationBundle))
        .onAppear { paths = store.launcherApps }
    }

    private func appRow(path: String) -> some View {
        let url = URL(fileURLWithPath: path)
        let icon = NSWorkspace.shared.icon(forFile: path)
        let name = url.deletingPathExtension().lastPathComponent
        return Label {
            Text(name)
        } icon: {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 20, height: 20)
        }
    }

    private func pickApps() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.begin { response in
            guard response == .OK else { return }
            let newPaths = panel.urls.map(\.path).filter { !paths.contains($0) }
            paths.append(contentsOf: newPaths)
            store.launcherApps = paths
        }
    }
}
