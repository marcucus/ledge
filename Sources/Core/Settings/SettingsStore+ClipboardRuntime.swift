import Foundation

public extension SettingsStore {
    /// Demande à `ClipboardModule` de retenter la dernière opération de persistance en échec
    /// (voir `clipboardPersistenceIssue`). Ne fait rien de plus que bumper un compteur observé :
    /// le retry lui-même vit dans le module, via sa boucle `observeSettings()` existante.
    func requestClipboardPersistenceRetry() {
        clipboardPersistenceRetryToken += 1
    }
}
