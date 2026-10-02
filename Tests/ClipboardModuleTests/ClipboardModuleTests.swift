import CryptoKit
@testable import ClipboardModule
import Core
import Foundation
import Testing

/// Double de test pour `ClipboardHistoryKeyStore` : garde la clé en mémoire au lieu du vrai
/// Trousseau de connexion, pour que les tests ne touchent jamais de Trousseau réel (doc 13,
/// Jalon 3, item 17). Classe (et non struct) pour que la clé générée survive entre les appels
/// `save()`/`load()` d'un même test, comme le ferait le vrai Trousseau.
final class InMemoryClipboardHistoryKeyStore: ClipboardHistoryKeyStore {
    private var cachedKey: SymmetricKey?

    func loadOrCreateKey() throws -> SymmetricKey {
        if let cachedKey { return cachedKey }
        let newKey = SymmetricKey(size: .bits256)
        cachedKey = newKey
        return newKey
    }
}

/// Reproduit la forme `Codable` de l'ancien format en clair (le vrai `Entry` de
/// `ClipboardHistoryStore` est `private`, donc inaccessible même via `@testable import`) — les
/// noms de champs doivent rester synchronisés avec `ClipboardHistoryStore.Entry`.
private struct LegacyPlaintextEntry: Codable {
    let id: UUID
    let date: Date
    let isPinned: Bool
    let kind: String
    let text: String?
    let urlString: String?
    let imageData: Data?
}

private final class WriteCounter {
    var count = 0
}

private final class ControllableWriter {
    var shouldFail = true

    func write(_ data: Data, to url: URL) throws {
        if shouldFail { throw CocoaError(.fileWriteNoPermission) }
        try data.write(to: url, options: .atomic)
    }
}

@MainActor
struct ClipboardModuleTests {
    @Test func pinnedItemsStayFirstAndEachGroupIsNewestFirst() {
        let old = Date(timeIntervalSince1970: 100)
        let recent = Date(timeIntervalSince1970: 200)
        let items = [
            ClipboardItem(content: .text("recent"), date: recent),
            ClipboardItem(content: .text("old pinned"), date: old, isPinned: true),
            ClipboardItem(content: .text("old"), date: old),
            ClipboardItem(content: .text("recent pinned"), date: recent, isPinned: true),
        ]

        let ordered = ClipboardModule.orderedForDisplay(items)

        #expect(ordered.map(\.content.previewText) == ["recent pinned", "old pinned", "recent", "old"])
    }

    // MARK: — ClipboardHistoryStore (doc 13, Jalon 2, point 12 : la persistance ne doit plus
    // échouer silencieusement — les opérations sont désormais `throws`, ce test couvre le
    // chemin nominal après ce changement).

    /// Répertoire temporaire isolé : ces tests ne doivent jamais toucher le vrai
    /// `Application Support/Ledge` de la machine (historique réel de l'utilisateur).
    private static func makeIsolatedStore() -> (store: ClipboardHistoryStore, fileURL: URL, cleanup: () -> Void) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ledge-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = ClipboardHistoryStore(directory: dir, keyStore: InMemoryClipboardHistoryKeyStore())
        let fileURL = dir.appendingPathComponent("clipboard-history.json")
        return (store, fileURL, { try? FileManager.default.removeItem(at: dir) })
    }

    @Test func savedHistoryRoundTripsThroughLoad() throws {
        let (store, _, cleanup) = Self.makeIsolatedStore()
        defer { cleanup() }
        let items = [
            ClipboardItem(content: .text("hello"), date: Date(timeIntervalSince1970: 1)),
            ClipboardItem(content: .text("pinned"), date: Date(timeIntervalSince1970: 2), isPinned: true),
        ]

        try store.save(items)
        let loaded = try store.load()

        #expect(loaded.map(\.content.previewText).sorted() == items.map(\.content.previewText).sorted())
    }

    @Test func clearRemovesPersistedHistory() throws {
        let (store, _, cleanup) = Self.makeIsolatedStore()
        defer { cleanup() }
        try store.save([ClipboardItem(content: .text("temp"))])

        try store.clear()

        #expect(try store.load().isEmpty)
    }

    @Test func persistedHistoryIsNotStoredAsPlaintextJSON() throws {
        let (store, fileURL, cleanup) = Self.makeIsolatedStore()
        defer { cleanup() }

        try store.save([ClipboardItem(content: .text("secret note"), date: Date(timeIntervalSince1970: 1))])

        let onDisk = try Data(contentsOf: fileURL)
        // Un fichier chiffré ne doit pas se décoder comme l'ancien format en clair, et son
        // contenu brut ne doit pas contenir le texte original en clair.
        #expect((try? JSONDecoder().decode([LegacyPlaintextEntry].self, from: onDisk)) == nil)
        #expect(String(data: onDisk, encoding: .utf8)?.contains("secret note") != true)
    }

    @Test func loadMigratesLegacyPlaintextFileAndReencryptsIt() throws {
        let (store, fileURL, cleanup) = Self.makeIsolatedStore()
        defer { cleanup() }

        let legacy = [
            LegacyPlaintextEntry(
                id: UUID(), date: Date(timeIntervalSince1970: 42), isPinned: false,
                kind: "text", text: "legacy in clear", urlString: nil, imageData: nil
            ),
        ]
        try JSONEncoder().encode(legacy).write(to: fileURL)

        let loaded = try store.load()
        #expect(loaded.map(\.content.previewText) == ["legacy in clear"])

        // La migration doit avoir rechiffré le fichier : il ne se décode plus comme l'ancien format.
        let rewritten = try Data(contentsOf: fileURL)
        #expect((try? JSONDecoder().decode([LegacyPlaintextEntry].self, from: rewritten)) == nil)

        // Un second load doit continuer de fonctionner via le chemin chiffré normal.
        let reloaded = try store.load()
        #expect(reloaded.map(\.content.previewText) == ["legacy in clear"])
    }

    @Test func legacyMigrationFailureIsReportedAndLeavesPlaintextUntouched() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ledge-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileURL = dir.appendingPathComponent("clipboard-history.json")
        let legacy = [
            LegacyPlaintextEntry(
                id: UUID(), date: Date(timeIntervalSince1970: 42), isPinned: false,
                kind: "text", text: "must remain readable", urlString: nil, imageData: nil
            ),
        ]
        let plaintext = try JSONEncoder().encode(legacy)
        try plaintext.write(to: fileURL)
        let store = ClipboardHistoryStore(
            directory: dir,
            keyStore: InMemoryClipboardHistoryKeyStore(),
            writeData: { _, _ in throw CocoaError(.fileWriteNoPermission) }
        )

        #expect(throws: Error.self) { try store.load() }
        #expect(try Data(contentsOf: fileURL) == plaintext)
    }

    @Test func failedLegacyMigrationExposesRecoverableLoadIssue() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ledge-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let legacy = [
            LegacyPlaintextEntry(
                id: UUID(), date: Date(), isPinned: false,
                kind: "text", text: "legacy", urlString: nil, imageData: nil
            ),
        ]
        try JSONEncoder().encode(legacy).write(to: dir.appendingPathComponent("clipboard-history.json"))
        let suiteName = "ledge.clipboard-migration.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults suite")
            return
        }
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        let settings = SettingsStore(defaults: defaults)
        settings.clipboardPersistEnabled = true
        let writer = ControllableWriter()
        let store = ClipboardHistoryStore(
            directory: dir,
            keyStore: InMemoryClipboardHistoryKeyStore(),
            writeData: writer.write
        )
        let module = ClipboardModule(settings: settings, source: ClipboardSource(), historyStore: store)
        defer { module.stop() }

        module.start()

        #expect(module.persistenceIssue == .loadFailed)

        writer.shouldFail = false
        settings.requestClipboardPersistenceRetry()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(module.persistenceIssue == nil)
        #expect(module.items.map(\.content.previewText) == ["legacy"])
    }

    @Test func settingsObservationDoesNotDuplicateAfterRestart() async {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ledge-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let suiteName = "ledge.clipboard-observation.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults suite")
            return
        }
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        let settings = SettingsStore(defaults: defaults)
        settings.clipboardPersistEnabled = false
        let counter = WriteCounter()
        let store = ClipboardHistoryStore(
            directory: dir,
            keyStore: InMemoryClipboardHistoryKeyStore(),
            writeData: { data, url in
                counter.count += 1
                try data.write(to: url, options: .atomic)
            }
        )
        let module = ClipboardModule(settings: settings, source: ClipboardSource(), historyStore: store)

        module.start()
        module.stop()
        module.start()
        settings.clipboardPersistEnabled = true
        try? await Task.sleep(for: .milliseconds(50))
        module.stop()

        #expect(counter.count == 1)
    }

    @Test func loadThrowsOnCorruptedFile() throws {
        let (store, fileURL, cleanup) = Self.makeIsolatedStore()
        defer { cleanup() }
        try Data("not json, not encrypted".utf8).write(to: fileURL)

        #expect(throws: Error.self) { try store.load() }
    }
}
