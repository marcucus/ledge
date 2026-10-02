@testable import MediaModule
import Testing

struct MediaSourceIdentityTests {
    @Test func appleMusicActiveBecomesTheSource() {
        let resolved = MediaSourceIdentity.resolved(current: .none, appleMusicIsActive: true)
        #expect(resolved == .appleMusic)
    }

    @Test func appleMusicActiveTakesOverFromAnotherSource() {
        // Ex. l'utilisateur lance Apple Music alors que Spotify jouait déjà.
        let resolved = MediaSourceIdentity.resolved(current: .other, appleMusicIsActive: true)
        #expect(resolved == .appleMusic)
    }

    @Test func appleMusicStoppingClearsItsOwnIdentity() {
        let resolved = MediaSourceIdentity.resolved(current: .appleMusic, appleMusicIsActive: false)
        #expect(resolved == .none)
    }

    @Test func appleMusicNoiseDoesNotStealAnotherSourceIdentity() {
        // Coeur du bug corrigé (doc 13, Jalon 3, item 15) : une notification Apple Music
        // "inactif" ne doit pas voler le statut de source à Spotify (ou toute autre app) qui
        // est déjà la source affichée.
        let resolved = MediaSourceIdentity.resolved(current: .other, appleMusicIsActive: false)
        #expect(resolved == .other)
    }

    @Test func remainsNoneWhenNothingIsActive() {
        let resolved = MediaSourceIdentity.resolved(current: .none, appleMusicIsActive: false)
        #expect(resolved == .none)
    }
}
