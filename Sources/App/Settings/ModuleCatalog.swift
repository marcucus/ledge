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
            settingsBuilder: { store in AnyView(MediaModuleSettingsView(store: store)) }
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
            settingsBuilder: { store in AnyView(DropZoneModuleSettingsView(store: store)) }
        ),
        Entry(
            id: "clipboard",
            icon: "doc.on.clipboard",
            nameKey: "module.clipboard.label",
            descriptionKey: "module.clipboard.description",
            settingsBuilder: { store in AnyView(ClipboardModuleSettingsView(store: store)) }
        ),
        // Le module Système n'est pas un onglet : il reste une simple source de statut (pastille
        // batterie de la NavBar, voir `AppDelegate.buildAndRegisterModules`). L'exposer ici
        // laisserait croire qu'un bascule "activé" ou un écran de réglages a un effet réel, alors
        // qu'aucun des deux n'en a — décision produit actée dans docs/13-audit-finalisation.md
        // (Jalon 2, point 11) : retirer les réglages trompeurs plutôt que réintégrer l'onglet.
        Entry(
            id: "shortcuts",
            icon: "bolt.fill",
            nameKey: "module.shortcuts.label",
            descriptionKey: "module.shortcuts.description",
            settingsBuilder: nil
        ),
        Entry(
            id: "calendar",
            icon: "calendar",
            nameKey: "module.calendar.label",
            descriptionKey: "module.calendar.description",
            settingsBuilder: nil
        ),
        Entry(
            id: "notes",
            icon: "note.text",
            nameKey: "module.notes.label",
            descriptionKey: "module.notes.description",
            settingsBuilder: nil
        ),
    ]

    static func entry(for id: String) -> Entry? {
        entries.first { $0.id == id }
    }
}
