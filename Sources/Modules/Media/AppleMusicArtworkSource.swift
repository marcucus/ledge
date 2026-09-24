import AppKit

/// Récupère la pochette d'Apple Music via ScriptingBridge (permission Automation).
///
/// MediaRemote ne fournit pas l'image pour Apple Music sur macOS 15 (run non-bundlé) et la
/// notification distribuée `com.apple.Music.playerInfo` n'en contient pas non plus. On lit
/// donc la pochette de la piste courante en process via `AppleMusicScriptingBridge`
/// (équivalent AppleScript, sans fork ni fichier temporaire). Le résultat est mis en cache
/// par piste pour ne faire l'appel qu'une fois. Échoue proprement (retourne `nil`) si Music
/// est absent, la permission refusée ou la piste sans pochette.
@MainActor
final class AppleMusicArtworkSource {
    private var cache: [String: NSImage] = [:]

    /// Pochette de la piste Apple Music en cours pour `key`, ou `nil`.
    func artwork(forTrackKey key: String) async -> NSImage? {
        if let cached = cache[key] { return cached }
        let fetched = await Task.detached { AppleMusicScriptingBridge.currentArtwork() }.value
        guard let image = fetched else { return nil }
        cache[key] = image
        return image
    }
}
