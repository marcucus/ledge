import Foundation

/// Métadonnées d'affichage des modules pour l'écran Réglages.
/// L'activation et l'ordre vivent dans `SettingsStore` ; ici on ne décrit que l'icône et le libellé.
enum ModuleCatalog {
    struct Entry: Identifiable {
        let id: String
        let icon: String
        let nameKey: String
    }

    static let entries: [Entry] = [
        Entry(id: "media", icon: "music.note", nameKey: "module.media.label"),
        Entry(id: "timers", icon: "timer", nameKey: "module.timers.label"),
        Entry(id: "dropzone", icon: "arrow.down.to.line", nameKey: "module.dropzone.label"),
        Entry(id: "clipboard", icon: "doc.on.clipboard", nameKey: "module.clipboard.label"),
        Entry(id: "system", icon: "cpu", nameKey: "module.system.label"),
    ]

    static func entry(for id: String) -> Entry? {
        entries.first { $0.id == id }
    }
}
