# 11 — Extensibilité : le contrat `NotchModule`

> Réponse à l'idée « SDK de plugin » de l'audit ([doc 10](10-audit-et-plan.md), section F).
> Documente le point d'extension **interne** existant. Ne couvre pas le chargement dynamique
> de plugins tiers — voir « Pourquoi pas de vrai SDK de plugin » ci-dessous.

## Le contrat

Tout module pluggable de Ledge implémente
[`NotchModule`](../Sources/Core/ModuleKit/NotchModule.swift) :

```swift
@MainActor
public protocol NotchModule: AnyObject {
    var id: String { get }
    var tabIcon: String { get }              // SF Symbol
    var tabLabel: LocalizedStringKey { get }
    func start()
    func stop()
    func makePeekView() -> AnyView
    func makeContentView() -> AnyView
}
```

`start()`/`stop()` ont des implémentations par défaut vides, et `makePeekView()`/
`makeContentView()` retournent `EmptyView()` par défaut — un module minimal n'a donc que
3 propriétés à fournir.

## Anatomie d'un module existant

Chaque module vit dans `Sources/Modules/<Nom>/` comme une **cible SPM autonome** qui ne
dépend que de `Core` (jamais d'un autre module — cf. [doc 08](08-conventions-de-code.md)) :

| Fichier type | Rôle |
|---|---|
| `<Nom>Module.swift` | `@MainActor @Observable final class` conforme à `NotchModule`. État observable + logique. |
| `<Nom>ContentView.swift` | Vue SwiftUI affichée dans le panneau ouvert (`expanded`). |
| `<Nom>PeekView.swift` | Vue compacte affichée en survol (`peeking`) — optionnelle. |

Exemple complet et simple à lire : [`Sources/Modules/Timer/`](../Sources/Modules/Timer/).

## Brancher un nouveau module (3 points d'assemblage)

1. **`Package.swift`** — déclarer la cible (`dependencies: ["Core"]`) et l'ajouter aux
   `dependencies` de la cible `App`.
2. **[`ModuleCatalog.swift`](../Sources/App/Settings/ModuleCatalog.swift)** — une `Entry`
   (icône, libellés localisés, vue de réglages optionnelle) pour que le module apparaisse
   dans l'écran Réglages → Modules.
3. **[`AppDelegate.swift`](../Sources/App/AppDelegate.swift)** — instancier le module et
   l'ajouter au tableau passé à `window.register(modules:)`.

Optionnel : contribuer au système **ambient** (pills affichées à côté de l'encoche au repos)
via `NotchController.setAmbient(_:sourceID:priority:)` — voir
[`AmbientContent.swift`](../Sources/Core/NotchWindow/AmbientContent.swift). La priorité la
plus haute gagne l'affichage quand plusieurs modules contribuent en même temps.

## Pourquoi pas de vrai SDK de plugin (chargement dynamique)

Un vrai SDK de plugin impliquerait de charger du **code tiers compilé** (`.bundle`/`.dylib`)
à l'exécution, hors du binaire signé/notarisé de Ledge. Concrètement :

- **Exécution de code arbitraire** : un plugin chargé dynamiquement tourne avec les mêmes
  droits que l'app — accès complet aux autres modules, au presse-papiers, aux fichiers, aux
  événements clavier interceptés par `SystemObserver`. Aucune sandbox ne le contiendrait
  (l'app elle-même n'est pas sandboxée, cf. [doc 09](09-avancement-et-contexte.md)).
- **Signature/notarisation** : Apple notarise le binaire de Ledge tel qu'il est distribué ;
  charger un binaire tiers non notarisé à l'exécution casse cette garantie pour l'utilisateur
  final, qui croit lancer une seule app de confiance.
- **Surface de maintenance** : un ABI de plugin stable à travers les versions de Ledge est un
  engagement à long terme (versionnement, dépréciation) disproportionné par rapport à la
  taille du projet aujourd'hui.

**Alternative retenue** : le contrat `NotchModule` reste un point d'extension **interne**,
réservé au code de ce dépôt. Si le besoin d'extensions tierces devient réel, la voie la plus
sûre serait un mécanisme **hors-process** (ex. extension via URL scheme / App Intents, ou un
protocole IPC explicite avec une liste blanche d'actions), pas du chargement de code — à
réévaluer si la demande se présente.
