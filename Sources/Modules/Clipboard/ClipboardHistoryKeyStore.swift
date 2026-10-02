import CryptoKit
import Foundation
import Security

/// Fournit la clé symétrique utilisée pour chiffrer l'historique persistant du presse-papiers
/// (doc 13, Jalon 3, item 17 : l'historique était auparavant enregistré en clair sur disque).
protocol ClipboardHistoryKeyStore {
    /// Retourne la clé existante, ou en génère et persiste une nouvelle si aucune n'existe encore.
    /// Doit toujours renvoyer la même clé tant qu'elle n'a pas été supprimée explicitement.
    func loadOrCreateKey() throws -> SymmetricKey
}

/// Stocke la clé dans le Trousseau macOS (`kSecClassGenericPassword`), jamais sur disque en
/// clair à côté du fichier qu'elle protège. Ledge n'étant pas sandboxé
/// (`com.apple.security.app-sandbox = false` dans `Scripts/App.entitlements`), aucun groupe
/// d'accès au Trousseau (`keychain-access-groups`) n'est nécessaire.
struct KeychainClipboardHistoryKeyStore: ClipboardHistoryKeyStore {
    /// Erreur Trousseau brute (`OSStatus`) — remontée telle quelle plutôt que traduite, la
    /// couche appelante (`ClipboardHistoryStore`) n'a besoin que de savoir que l'opération a
    /// échoué pour basculer sur un état visible et récupérable (doc 13, Jalon 2, point 12).
    struct KeychainError: Error {
        let status: OSStatus
    }

    private static let service = "me.adrienmarques.ledge.clipboard-history-key"
    private static let account = "clipboard-history"

    func loadOrCreateKey() throws -> SymmetricKey {
        if let existing = try readKey() {
            return existing
        }
        let newKey = SymmetricKey(size: .bits256)
        try store(newKey)
        return newKey
    }

    private func readKey() throws -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { return nil }
            return SymmetricKey(data: data)
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError(status: status)
        }
    }

    private func store(_ key: SymmetricKey) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account
        ]
        // Repart d'un état propre à chaque création : un ancien item invalide ne doit jamais
        // empêcher silencieusement l'enregistrement de la nouvelle clé. Le statut de la
        // suppression n'est volontairement pas vérifié : "rien à supprimer" est un cas normal.
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }
}
