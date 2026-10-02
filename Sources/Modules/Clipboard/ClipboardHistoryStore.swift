import AppKit
import CryptoKit
import Foundation

/// Persiste l'historique du presse-papiers sur disque, chiffré (AES-GCM via CryptoKit, clé dans
/// le Trousseau — voir `ClipboardHistoryKeyStore`), uniquement si l'utilisateur a activé
/// l'option correspondante — RAM seulement par défaut (cf. doc 03, confidentialité : un
/// historique de presse-papiers est sensible). Un fichier laissé en clair par une version
/// antérieure à ce chiffrement (doc 13, Jalon 3, item 17) est relu une dernière fois puis
/// rechiffré immédiatement par `load()`, sans jamais réécrire de copie en clair.
///
/// Les trois opérations sont désormais `throws` : `ClipboardModule` capture l'échec et
/// l'expose comme un état visible et récupérable (`persistenceIssue`) plutôt que de l'avaler
/// silencieusement (doc 13, Jalon 2, point 12).
struct ClipboardHistoryStore {
    private let fileURL: URL?
    private let keyStore: ClipboardHistoryKeyStore
    private let writeData: (Data, URL) throws -> Void

    /// Répertoire Application Support introuvable : ne peut arriver qu'en environnement anormal
    /// (sandbox cassée, disque en lecture seule…), mais doit rester un échec explicite plutôt
    /// qu'un no-op silencieux.
    struct UnavailableDirectoryError: Error {}

    /// La clé de chiffrement n'a pas pu être lue ni créée dans le Trousseau.
    struct KeyUnavailableError: Error {
        let underlying: Error
    }

    /// Les octets lus sur disque ne sont ni un historique chiffré valide pour la clé actuelle,
    /// ni l'ancien format en clair — fichier corrompu ou étranger. Couvre aussi le cas (jamais
    /// rencontré en pratique) où le scellement AES-GCM ne produirait pas de forme combinée.
    struct CorruptedHistoryError: Error {}

    /// `directory` et `keyStore` sont injectables pour les tests (répertoire temporaire isolé,
    /// clé en mémoire plutôt que le vrai Trousseau) ; en production, les appels sans argument
    /// résolvent toujours `Application Support/Ledge` et `KeychainClipboardHistoryKeyStore`.
    init(
        directory: URL? = nil,
        keyStore: ClipboardHistoryKeyStore = KeychainClipboardHistoryKeyStore(),
        writeData: @escaping (Data, URL) throws -> Void = { data, url in
            try data.write(to: url, options: .atomic)
        }
    ) {
        self.writeData = writeData
        guard let appDir = directory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent("Ledge", isDirectory: true)
        else {
            fileURL = nil
            self.keyStore = keyStore
            return
        }
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        fileURL = appDir.appendingPathComponent("clipboard-history.json")
        self.keyStore = keyStore
    }

    func load() throws -> [ClipboardItem] {
        guard let fileURL else { throw UnavailableDirectoryError() }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        let key = try obtainKey()

        if let items = try? decryptedEntries(from: data, key: key) {
            return items
        }
        // Pas un historique chiffré valide : tente l'ancien format en clair, puis rechiffre
        // immédiatement pour ne jamais laisser cette copie en clair au-delà de cette migration.
        guard let legacyItems = try? decodeEntries(from: data) else {
            throw CorruptedHistoryError()
        }
        try save(legacyItems, key: key)
        return legacyItems
    }

    func save(_ items: [ClipboardItem]) throws {
        try save(items, key: obtainKey())
    }

    private func save(_ items: [ClipboardItem], key: SymmetricKey) throws {
        guard let fileURL else { throw UnavailableDirectoryError() }
        let plaintext = try JSONEncoder().encode(items.map(Entry.init))
        let sealedBox = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealedBox.combined else { throw CorruptedHistoryError() }
        try writeData(combined, fileURL)
    }

    private func obtainKey() throws -> SymmetricKey {
        do {
            return try keyStore.loadOrCreateKey()
        } catch {
            throw KeyUnavailableError(underlying: error)
        }
    }

    private func decryptedEntries(from data: Data, key: SymmetricKey) throws -> [ClipboardItem] {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let plaintext = try AES.GCM.open(sealedBox, using: key)
        return try decodeEntries(from: plaintext)
    }

    private func decodeEntries(from data: Data) throws -> [ClipboardItem] {
        let entries = try JSONDecoder().decode([Entry].self, from: data)
        return entries.compactMap { $0.makeClipboardItem() }
    }

    /// Supprime le fichier — appelé quand l'utilisateur vide l'historique ou désactive la
    /// persistance, pour ne pas laisser de données sensibles sur disque sans y consentir.
    func clear() throws {
        guard let fileURL else { return }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
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
