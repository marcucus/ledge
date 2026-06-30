import AppKit
import ScriptingBridge

/// Pilote la position de lecture d'Apple Music en process, sans fork d'`osascript`.
///
/// Utilise `SBApplication` en accès dynamique par clé ("playerPosition" — équivalent
/// Objective-C de la propriété AppleScript "player position", code à 4 lettres `pPos`
/// confirmé via `sdef`) : pas besoin de générer l'en-tête via `sdef`/`sdp`, ce qui aurait
/// demandé une cible Objective-C dans ce paquet SPM sans projet Xcode. Même mécanisme bas
/// niveau (Apple Events) que l'AppleScript via osascript, mais sans le coût d'un process à
/// chaque appel — pertinent ici car le resync de position tourne toutes les 5 s pendant la
/// lecture. Un délégué est requis : sans lui, `SBApplication` lève une exception
/// Objective-C (non rattrapable en Swift) au lieu de simplement échouer.
enum AppleMusicScriptingBridge {
    private static let bundleIdentifier = "com.apple.Music"
    private nonisolated(unsafe) static var cachedApp: SBApplication?
    private nonisolated(unsafe) static let delegate = FailureSwallowingDelegate()

    private nonisolated static func app() -> SBApplication? {
        if let cachedApp { return cachedApp }
        guard let app = SBApplication(bundleIdentifier: bundleIdentifier) else { return nil }
        app.delegate = delegate
        cachedApp = app
        return app
    }

    /// Position de lecture courante (secondes), ou `nil` si indisponible.
    nonisolated static func playerPosition() -> Double? {
        guard let app = app() else { return nil }
        delegate.lastError = nil
        guard let value = app.value(forKey: "playerPosition") as? Double, delegate.lastError == nil else {
            return nil
        }
        return value
    }

    /// Positionne la lecture. Retourne `false` si l'évènement Apple a échoué.
    @discardableResult
    nonisolated static func setPlayerPosition(_ value: Double) -> Bool {
        guard let app = app() else { return false }
        delegate.lastError = nil
        app.setValue(value, forKey: "playerPosition")
        return delegate.lastError == nil
    }

    /// Pochette de la piste en cours, ou `nil` (pas de lecture, pas de pochette, permission
    /// refusée…). Remplace l'ancien export AppleScript "raw data" vers un fichier temporaire :
    /// la propriété sdef "data" de la classe "artwork" est de type "picture", que
    /// ScriptingBridge convertit directement en `NSImage` — pas de fichier intermédiaire.
    nonisolated static func currentArtwork() -> NSImage? {
        guard let app = app() else { return nil }
        delegate.lastError = nil
        guard let track = app.value(forKey: "currentTrack") as? SBObject,
              let artworks = track.value(forKey: "artworks") as? SBElementArray,
              let artwork = artworks.firstObject as? SBObject,
              let image = artwork.value(forKey: "data") as? NSImage,
              delegate.lastError == nil
        else { return nil }
        return image
    }
}

/// Absorbe les erreurs d'évènement Apple pour que `SBApplication` échoue silencieusement
/// (retourne `nil`/ne fait rien) au lieu de lever une exception Objective-C.
private final class FailureSwallowingDelegate: NSObject, SBApplicationDelegate {
    nonisolated(unsafe) var lastError: Error?

    func eventDidFail(_ event: UnsafePointer<AppleEvent>, withError error: Error) -> Any? {
        lastError = error
        return nil
    }
}
