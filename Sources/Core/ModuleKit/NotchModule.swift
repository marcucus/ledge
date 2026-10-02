import SwiftUI

/// Contrat d'un module pluggable de l'encoche.
///
/// Trois notions distinctes régissent la présence d'un module, précisées par le Jalon 2 de
/// `docs/13-audit-finalisation.md` :
/// - **visible** : le module apparaît dans la navigation (onglet ou grille). Propriété purement
///   UI, calculée par `NotchController.visibleModules` — jamais stockée pour elle-même.
/// - **enabled** : le module est actif. Décidé par `SettingsStore` (réglages globaux) ou par
///   l'`AppProfile` de l'app au premier plan s'il y en a un ; un module désactivé n'est jamais
///   visible (l'inverse n'est pas garanti : un module peut être activé mais placé en `.hidden`
///   dans la composition courante, donc invisible sans être arrêté).
/// - **captureEnabled** : cas particulier de `ClipboardModule`, où « activé » et « capture »
///   sont une seule et même chose — désactiver le module arrête réellement la capture
///   (confidentialité, voir `ClipboardSource.stop()`).
///
/// `NotchController` est la seule source de vérité qui relie ces notions au cycle de vie réel :
/// `start()` est appelé exactement quand le module devient activé (jamais à l'enregistrement
/// seul), `stop()` exactement quand il cesse de l'être — que ce soit via les réglages globaux ou
/// via un profil d'app. Un module doit donc réellement cesser toute activité observable
/// (timers, observateurs, permissions actives) dans `stop()`, pas seulement masquer sa vue.
@MainActor
public protocol NotchModule: AnyObject {
    var id: String { get }
    var tabIcon: String { get }
    var tabLabel: LocalizedStringKey { get }
    /// Appelé quand le module devient activé. Doit démarrer toute son activité (observateurs,
    /// polling, permissions) — jamais appelé « juste au cas où » à l'enregistrement.
    func start()
    /// Appelé quand le module cesse d'être activé (réglages ou profil d'app). Doit arrêter
    /// réellement toute activité démarrée par `start()` : un module désactivé ne doit rien
    /// observer ni capturer, même s'il reste instancié en mémoire.
    func stop()
    func makePeekView() -> AnyView
    func makeContentView() -> AnyView
}

public extension NotchModule {
    func stop() {}
    func makePeekView() -> AnyView {
        AnyView(EmptyView())
    }

    func makeContentView() -> AnyView {
        AnyView(EmptyView())
    }
}
