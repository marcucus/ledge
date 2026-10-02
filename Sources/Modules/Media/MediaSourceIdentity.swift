import Foundation

/// Identité explicite de l'application qui pilote actuellement `MediaModule.nowPlaying`
/// (doc 13, Jalon 3, item 15).
///
/// Avant l'introduction de ce type, deux booléens (`sourceIsAppleMusic`/`sourceIsSpotify`)
/// étaient mis à jour indépendamment depuis des canaux différents (notification distribuée
/// `com.apple.Music.playerInfo`, sondage `NSWorkspace.runningApplications` dans `refresh()`).
/// Ils pouvaient se désynchroniser quand plusieurs lecteurs étaient ouverts en même temps :
/// une notification Apple Music « inactif » écrasait sans condition l'état affiché, même si
/// Spotify était la source réellement en cours de lecture, et `seek(to:)` pouvait alors
/// continuer de router vers Apple Music via AppleScript alors que ce n'était plus la bonne app.
enum MediaSourceIdentity: Equatable {
    /// Aucune source active identifiée.
    case none
    /// Apple Music, confirmé par sa notification distribuée dédiée.
    case appleMusic
    /// Toute autre source (Spotify, navigateur, etc.), vue uniquement via MediaRemote.
    case other

    /// Calcule la nouvelle identité à partir du dernier évènement Apple Music reçu, sans
    /// jamais laisser un évènement Apple Music non pertinent voler la source à une autre
    /// application : seule l'app qui a effectivement perdu l'activité perd son statut.
    static func resolved(current: MediaSourceIdentity, appleMusicIsActive: Bool) -> MediaSourceIdentity {
        if appleMusicIsActive { return .appleMusic }
        return current == .appleMusic ? .none : current
    }
}
