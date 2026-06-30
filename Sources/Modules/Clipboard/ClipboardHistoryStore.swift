import AppKit
import Foundation

/// Persiste l'historique du presse-papiers sur disque (JSON dans Application Support),
/// uniquement si l'utilisateur a activé l'option correspondante — RAM seulement par défaut
/// (cf. doc 03, confidentialité : un historique de presse-papiers est sensible).
struct ClipboardHistoryStore {
    private let fileURL: URL?

    init() {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else {
            fileURL = nil
            return
        }
        let appDir = dir.appendingPathComponent("Ledge", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        fileURL = appDir.appendingPathComponent("clipboard-history.json")
    }

    func load() -> [ClipboardItem] {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return [] }
        guard let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        return entries.compactMap { $0.makeClipboardItem() }
    }

    func save(_ items: [ClipboardItem]) {
        guard let fileURL else { return }
        guard let data = try? JSONEncoder().encode(items.map(Entry.init)) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Supprime le fichier — appelé quand l'utilisateur vide l'historique ou désactive la
    /// persistance, pour ne pas laisser de données sensibles sur disque sans y consentir.
    func clear() {
        guard let fileURL else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: — Représentation Codable

    private struct Entry: Codable {
        let id: UUID
        let date: Date
        let isPinned: Bool
        let kind: String
        let text: String?
        let urlString: String?
        let imageData: Data?

        init(item: ClipboardItem) {
            id = item.id
            date = item.date
            isPinned = item.isPinned
            switch item.content {
            case let .text(text):
                kind = "text"
                self.text = text
                urlString = nil
                imageData = nil
            case let .url(url):
                kind = "url"
                text = nil
                urlString = url.absoluteString
                imageData = nil
            case let .image(image):
                kind = "image"
                text = nil
                urlString = nil
                imageData = image.tiffRepresentation
            }
        }

        func makeClipboardItem() -> ClipboardItem? {
            switch kind {
            case "text":
                guard let text else { return nil }
                return ClipboardItem(id: id, content: .text(text), date: date, isPinned: isPinned)
            case "url":
                guard let urlString, let url = URL(string: urlString) else { return nil }
                return ClipboardItem(id: id, content: .url(url), date: date, isPinned: isPinned)
            case "image":
                guard let imageData, let image = NSImage(data: imageData) else { return nil }
                return ClipboardItem(id: id, content: .image(image), date: date, isPinned: isPinned)
            default:
                return nil
            }
        }
    }
}
