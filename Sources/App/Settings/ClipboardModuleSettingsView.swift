import AppKit
import Core
import SwiftUI

struct ClipboardModuleSettingsView: View {
    var store: SettingsStore

    /// Reflète `store.clipboardExcludedApps` localement pour piloter `.onDelete`/insertion sans
    /// aller-retour ; réécrit vers `store` à chaque modification (même schéma que
    /// les applications exclues du presse-papiers).
    @State private var excludedApps: [String] = []

    var body: some View {
        Form {
            Section {
                Picker(selection: Binding(
                    get: { store.clipboardMaxItems },
                    set: { store.clipboardMaxItems = $0 }
                )) {
                    Text("settings.modules.clipboard.maxItems.25", bundle: localizationBundle).tag(25)
                    Text("settings.modules.clipboard.maxItems.50", bundle: localizationBundle).tag(50)
                    Text("settings.modules.clipboard.maxItems.100", bundle: localizationBundle).tag(100)
                    Text("settings.modules.clipboard.maxItems.unlimited", bundle: localizationBundle).tag(0)
                } label: {
                    Text("settings.modules.clipboard.maxItems", bundle: localizationBundle)
                }
            }

            Section {
                Toggle(isOn: Binding(
                    get: { store.clipboardPersistEnabled },
                    set: { store.clipboardPersistEnabled = $0 }
                )) {
                    Text("settings.modules.clipboard.persist", bundle: localizationBundle)
                }
            } footer: {
                Text("settings.modules.clipboard.persist.hint", bundle: localizationBundle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let issue = store.clipboardPersistenceIssue {
                persistenceIssueSection(issue)
            }

            excludedAppsSection
        }
        .formStyle(.grouped)
        .navigationTitle(Text("module.clipboard.label", bundle: localizationBundle))
        .onAppear { excludedApps = store.clipboardExcludedApps }
    }

    /// Liste d'exclusion (doc 13, Jalon 3, item 18) : les copies faites depuis une de ces apps
    /// ne sont jamais ajoutées à l'historique (voir `ClipboardSource.sourceBundleIdentifier`).
    private var excludedAppsSection: some View {
        Section {
            ForEach(excludedApps, id: \.self) { bundleIdentifier in
                excludedAppRow(bundleIdentifier: bundleIdentifier)
            }
            .onDelete { offsets in
                excludedApps.remove(atOffsets: offsets)
                store.clipboardExcludedApps = excludedApps
            }

            Button {
                pickAppToExclude()
            } label: {
                Label(
                    LocalizedStringKey("settings.modules.clipboard.excludedApps.add"),
                    systemImage: "plus"
                )
            }
        } header: {
            Text("settings.modules.clipboard.excludedApps", bundle: localizationBundle)
        } footer: {
            Text("settings.modules.clipboard.excludedApps.hint", bundle: localizationBundle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func excludedAppRow(bundleIdentifier: String) -> some View {
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
        let name = url?.deletingPathExtension().lastPathComponent ?? bundleIdentifier
        return Label {
            Text(name)
        } icon: {
            if let url {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "app.dashed")
            }
        }
    }

    private func pickAppToExclude() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.begin { response in
            guard response == .OK else { return }
            let newIdentifiers = panel.urls
                .compactMap { Bundle(url: $0)?.bundleIdentifier }
                .filter { !excludedApps.contains($0) }
            excludedApps.append(contentsOf: newIdentifiers)
            store.clipboardExcludedApps = excludedApps
        }
    }

    /// État visible et récupérable (doc 13, Jalon 2, point 12) : la persistance sur disque a
    /// échoué, mais la capture en mémoire continue normalement — on le dit, et on permet de
    /// réessayer plutôt que d'avaler l'erreur.
    private func persistenceIssueSection(_ issue: ClipboardPersistenceIssue) -> some View {
        Section {
            Label {
                Text(messageKey(for: issue), bundle: localizationBundle)
            } icon: {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            Button {
                store.requestClipboardPersistenceRetry()
            } label: {
                Text("action.retry", bundle: localizationBundle)
            }
        }
    }

    private func messageKey(for issue: ClipboardPersistenceIssue) -> LocalizedStringKey {
        switch issue {
        case .loadFailed: "clipboard.persistence.error.load"
        case .saveFailed: "clipboard.persistence.error.save"
        case .clearFailed: "clipboard.persistence.error.clear"
        }
    }
}
