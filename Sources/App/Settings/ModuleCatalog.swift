import Core
import SwiftUI

/// Métadonnées d'affichage des modules pour l'écran Réglages.
/// L'activation et l'ordre vivent dans `SettingsStore` ; ici on ne décrit que l'icône, le libellé,
/// la description et le builder de vue de réglages spécifiques au module.
enum ModuleCatalog {
    struct Entry: Identifiable {
        let id: String
        let icon: String
        let nameKey: String
        let descriptionKey: String
        let settingsBuilder: ((SettingsStore) -> AnyView)?
    }

    static let entries: [Entry] = [
        Entry(
            id: "media",
            icon: "music.note",
            nameKey: "module.media.label",
            descriptionKey: "module.media.description",
            settingsBuilder: nil
        ),
        Entry(
            id: "timers",
            icon: "timer",
            nameKey: "module.timers.label",
            descriptionKey: "module.timers.description",
            settingsBuilder: { store in AnyView(TimerModuleSettingsView(store: store)) }
        ),
        Entry(
            id: "dropzone",
            icon: "arrow.down.to.line",
            nameKey: "module.dropzone.label",
            descriptionKey: "module.dropzone.description",
            settingsBuilder: nil
        ),
        Entry(
            id: "clipboard",
            icon: "doc.on.clipboard",
            nameKey: "module.clipboard.label",
            descriptionKey: "module.clipboard.description",
            settingsBuilder: { store in AnyView(ClipboardModuleSettingsView(store: store)) }
        ),
        Entry(
            id: "system",
            icon: "cpu",
            nameKey: "module.system.label",
            descriptionKey: "module.system.description",
            settingsBuilder: nil
        ),
    ]

    static func entry(for id: String) -> Entry? {
        entries.first { $0.id == id }
    }
}
