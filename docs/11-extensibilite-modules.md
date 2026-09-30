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

### Contrat précis de `start()`/`stop()` (depuis le Jalon 2 de [doc 13](13-audit-finalisation.md))

Trois notions distinctes régissent la présence d'un module :

- **visible** — apparaît dans la navigation. Purement UI (`NotchController.visibleModules`),
  jamais stocké pour lui-même.
- **enabled** — activé par les réglages globaux ou par l'`AppProfile` de l'app au premier
  plan. `NotchController` est la seule source de vérité qui relie `enabled` au cycle de vie
  réel : `start()` est appelé exactement quand un module devient activé, `stop()` exactement
  quand il cesse de l'être (voir
  [`NotchController+ModuleLifecycle.swift`](../Sources/Core/NotchWindow/NotchController+ModuleLifecycle.swift)).
  Un module **ne doit jamais** démarrer son activité ailleurs qu'à `start()`, ni continuer à
  observer/capturer quoi que ce soit après `stop()` — c'est ce qui garantit, par exemple,
  qu'un presse-papiers désactivé ne capture plus rien.
- **destructive** — `stop()` suspend l'activité mais ne doit pas supprimer les données métier
  persistées : un profil d'app peut désactiver temporairement un module. Toute suppression
  définitive doit passer par une action explicite distincte (par exemple
  `TimerModule.clearAllTimers()`). À la reprise, le module resynchronise son état depuis les
  échéances ou données persistées.
- **captureEnabled** — cas particulier du presse-papiers, où « activé » et « capture » sont
  une seule et même chose : voir `ClipboardModule.stop()`.

Un module qui échoue à respecter ceci (par exemple un observateur démarré dans `init()`) rend
son toggle « activé » dans Réglages → Modules trompeur — exactement le bug corrigé par le
Jalon 2.

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
   dans l'écran Réglages → Modules. N'ajouter une `Entry` que si le module est réellement
   enregistré comme onglet dans `AppDelegate` : sinon son toggle « activé » n'aurait aucun
   effet (cf. la décision prise pour Système, qui reste volontairement hors catalogue).
3. **[`AppDelegate.swift`](../Sources/App/AppDelegate.swift)** — instancier le module et
   l'ajouter au tableau passé à `window.register(modules:)`.

Optionnel : contribuer au système **ambient** (pills affichées à côté de l'encoche au repos)
via `NotchController.setAmbient(_:sourceID:priority:)` — voir
[`AmbientContent.swift`](../Sources/Core/NotchWindow/AmbientContent.swift). La priorité la
plus haute gagne l'affichage quand plusieurs modules contribuent en même temps.

## Pourquoi pas de vrai SDK de plugin (chargement dynamique)

Un vrai SDK de plugin impliquerait de charger du **code tiers compilé** (`.bundle`/`.dylib`)
à l'exécution, hors du bundle de Ledge tel qu'il a été publié. Concrètement :

- **Exécution de code arbitraire** : un plugin chargé dynamiquement tourne avec les mêmes
  droits que l'app — accès complet aux autres modules, au presse-papiers, aux fichiers, aux
  événements clavier interceptés par `SystemObserver`. Aucune sandbox ne le contiendrait
  (l'app elle-même n'est pas sandboxée, cf. [doc 09](09-avancement-et-contexte.md)).
- **Intégrité** : Ledge publie un bundle fixe dont le DMG est signé avec Sparkle EdDSA ; charger un
  binaire tiers arbitraire à l'exécution casse cette garantie pour l'utilisateur
  final, qui croit lancer une seule app de confiance.
- **Surface de maintenance** : un ABI de plugin stable à travers les versions de Ledge est un
  engagement à long terme (versionnement, dépréciation) disproportionné par rapport à la
  taille du projet aujourd'hui.

**Alternative retenue** : le contrat `NotchModule` reste un point d'extension **interne**,
réservé au code de ce dépôt. Si le besoin d'extensions tierces devient réel, la voie la plus
sûre serait un mécanisme **hors-process** (ex. extension via URL scheme / App Intents, ou un
protocole IPC explicite avec une liste blanche d'actions), pas du chargement de code — à
réévaluer si la demande se présente.
