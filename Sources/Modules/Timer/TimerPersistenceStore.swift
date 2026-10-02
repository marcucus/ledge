import Foundation

/// Persiste les timers actifs sur disque (JSON dans Application Support), pour les retrouver
/// après un quit/relaunch (doc 13, Jalon 3, item 19 : ils étaient auparavant systématiquement
/// perdus). Contrairement à l'historique du presse-papiers (doc 13, Jalon 3, item 17), ce n'a
/// pas besoin de chiffrement : ce ne sont que des durées et libellés saisis pour la session en
/// cours, pas un historique cumulé de données potentiellement sensibles.
///
/// `public` parce que `TimerModule.init(persistenceStore:)` l'expose. Les opérations restent
/// internes au module ; l'initialiseur de handlers permet aux tests de simuler chaque panne.
public struct TimerPersistenceStore {
    private let loadHandler: () throws -> PersistedTimerState
    private let saveHandler: (PersistedTimerState) throws -> Void
    private let clearHandler: () throws -> Void

    /// Répertoire Application Support introuvable : échec explicite remonté à `TimerModule`, qui
    /// conserve les timers en mémoire et expose une action de reprise à l'utilisateur.
    struct UnavailableDirectoryError: Error {}

    /// `directory` est injectable pour les tests (répertoire temporaire isolé) ; en production,
    /// l'appel sans argument résout toujours `Application Support/Ledge`, comme `ClipboardHistoryStore`.
    public init(directory: URL? = nil) {
        let appDir = directory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent("Ledge", isDirectory: true)
        let fileURL = appDir?.appendingPathComponent("timers.json")
        loadHandler = { try Self.load(from: fileURL) }
        saveHandler = { try Self.save($0, to: fileURL, directory: appDir) }
        clearHandler = { try Self.clear(fileURL) }
    }

    init(
        load: @escaping () throws -> PersistedTimerState,
        save: @escaping (PersistedTimerState) throws -> Void,
        clear: @escaping () throws -> Void
    ) {
        loadHandler = load
        saveHandler = save
        clearHandler = clear
    }

    func load() throws -> PersistedTimerState {
        try loadHandler()
    }

    func save(_ state: PersistedTimerState) throws {
        try saveHandler(state)
    }

    func clear() throws {
        try clearHandler()
    }

    private static func load(from fileURL: URL?) throws -> PersistedTimerState {
        guard let fileURL else { throw UnavailableDirectoryError() }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .empty }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(PersistedTimerState.self, from: data)
    }

    private static func save(_ state: PersistedTimerState, to fileURL: URL?, directory: URL?) throws {
        guard let fileURL, let directory else { throw UnavailableDirectoryError() }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(state)
        try data.write(to: fileURL, options: .atomic)
    }

    private static func clear(_ fileURL: URL?) throws {
        guard let fileURL else { return }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}
