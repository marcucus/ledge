import AppKit
import Foundation

/// Récupère la pochette Spotify via AppleScript (artwork url) + URLSession.
/// Nécessite la permission Automation pour Spotify (accordée au premier accès).
@MainActor
final class SpotifyArtworkSource {
    private var cache: [String: NSImage] = [:]

    func artwork(forTrackKey key: String) async -> NSImage? {
        if let cached = cache[key] { return cached }
        guard let url = await Self.currentArtworkURL() else { return nil }
        guard let image = await Self.download(from: url) else { return nil }
        cache[key] = image
        return image
    }

    private nonisolated static func currentArtworkURL() async -> URL? {
        let script = """
        tell application "Spotify"
            if player state is stopped then return ""
            return artwork url of current track
        end tell
        """
        let result = await runOsascript(script)
        guard !result.isEmpty, let url = URL(string: result) else { return nil }
        return url
    }

    private nonisolated static func download(from url: URL) async -> NSImage? {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return NSImage(data: data)
    }

    private nonisolated static func runOsascript(_ script: String) async -> String {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let str = (String(data: data, encoding: .utf8) ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: str)
            }
            do { try process.run() } catch { continuation.resume(returning: "") }
        }
    }
}
