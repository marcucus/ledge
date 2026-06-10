import Foundation

// Protocole complété au démarrage de V1 — chaque module fournit
// son icône, sa vue aperçu, sa vue ouverte et ses réglages.
protocol NotchModule: AnyObject {
    var id: String { get }
}
