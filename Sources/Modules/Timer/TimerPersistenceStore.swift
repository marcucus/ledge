import Foundation

/// Instantané persistable de l'état du module Timer (doc 13, Jalon 3, item 19).
struct PersistedTimerState: Codable {
    var entries: [TimerEntry]
    var pomodoroEntryID: UUID?
    var pomodoroState: PomodoroState

    static let empty = PersistedTimerState(entries: [], pomodoroEntryID: nil, pomodoroState: PomodoroState())
}

/// Persiste les timers actifs sur disque (JSON dans Application Support), pour les retrouver
/// après un quit/relaunch (doc 13, Jalon 3, item 19 : ils étaient auparavant systématiquement
/// perdus). Contrairement à l'historique du presse-papiers (doc 13, Jalon 3, item 17), ce n'a
/// pas besoin de chiffrement : ce ne sont que des durées et libellés saisis pour la session en
/// cours, pas un historique cumulé de données potentiellement sensibles.
///
/// `public` (et son `init(directory:)`) parce que `TimerModule.init(persistenceStore:)` est
/// `public` avec une valeur par défaut : Swift exige que tout type apparaissant dans la
/// signature d'une API publique soit au moins aussi visible qu'elle. `load()`/`save()`/`clear()`
/// restent `internal`, `TimerModuleTests` ne les appelle jamais directement.
public struct TimerPersistenceStore {
    private let fileURL: URL?

    /// Répertoire Application Support introuvable : reste un échec explicite (`throws`) plutôt
    /// qu'un no-op silencieux, même si `TimerModule` choisit délibérément d'ignorer cet échec
    /// avec `try?` — une persistance en échec ne doit jamais empêcher un timer de fonctionner.
    struct UnavailableDirectoryError: Error {}

    /// `directory` est injectable pour les tests (répertoire temporaire isolé) ; en production,
    /// l'appel sans argument résout toujours `Application Support/Ledge`, comme `ClipboardHistoryStore`.
    public init(directory: URL? = nil) {
        guard let appDir = directory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent("Ledge", isDirectory: true)
        else {
            fileURL = nil
            return
        }
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        fileURL = appDir.appendingPathComponent("timers.json")
    }

    func load() throws -> PersistedTimerState {
        guard let fileURL else { throw UnavailableDirectoryError() }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .empty }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(PersistedTimerState.self, from: data)
    }

    func save(_ state: PersistedTimerState) throws {
        guard let fileURL else { throw UnavailableDirectoryError() }
        let data = try JSONEncoder().encode(state)
        try data.write(to: fileURL, options: .atomic)
    }

    func clear() throws {
        guard let fileURL else { return }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}
