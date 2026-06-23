import AppKit

/// Récupère la pochette d'Apple Music via AppleScript (permission Automation).
///
/// MediaRemote ne fournit pas l'image pour Apple Music sur macOS 15 (run non-bundlé) et la
/// notification distribuée `com.apple.Music.playerInfo` n'en contient pas non plus. On exporte
/// donc la pochette de la piste courante vers un fichier temporaire via `osascript`, puis on la
/// charge. Le résultat est mis en cache par piste pour ne lancer le script qu'une fois.
/// Échoue proprement (retourne `nil`) si Music est absent, la permission refusée ou la piste sans pochette.
@MainActor
final class AppleMusicArtworkSource {
    private var cache: [String: NSImage] = [:]

    /// Pochette de la piste Apple Music en cours pour `key`, ou `nil`.
    func artwork(forTrackKey key: String) async -> NSImage? {
        if let cached = cache[key] { return cached }
        guard let data = await Self.exportCurrentArtwork(), let image = NSImage(data: data) else {
            return nil
        }
        cache[key] = image
        return image
    }

    /// Exporte la pochette de la piste courante vers un fichier temp et en lit les octets.
    private nonisolated static func exportCurrentArtwork() async -> Data? {
        let path = NSTemporaryDirectory() + "ledge-artwork.dat"
        let succeeded = await runScript(artworkScript(toPath: path)).contains("ok")
        guard succeeded else { return nil }
        let url = URL(fileURLWithPath: path)
        let data = try? Data(contentsOf: url)
        try? FileManager.default.removeItem(at: url)
        return data
    }

    private nonisolated static func artworkScript(toPath path: String) -> String {
        """
        tell application "Music"
            if player state is stopped then return ""
            try
                set theData to (get raw data of artwork 1 of current track)
            on error
                return ""
            end try
        end tell
        set outFile to (POSIX file "\(path)")
        set fileRef to open for access outFile with write permission
        set eof fileRef to 0
        write theData to fileRef
        close access fileRef
        return "ok"
        """
    }

    /// Lance `osascript` hors du main thread (terminaison sur file de fond) et renvoie sa sortie.
    private nonisolated static func runScript(_ script: String) async -> String {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            let output = Pipe()
            process.standardOutput = output
            process.standardError = Pipe()
            process.terminationHandler = { _ in
                let data = output.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: "")
            }
        }
    }
}
