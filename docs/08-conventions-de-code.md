# 08 — Conventions de code & standards

> La constitution du code de Ledge. Objectif : **structure parfaite, qualité maximale,
> minimum de lignes** — sans jamais sacrifier la lisibilité au profit de la concision.
> Toute contribution au projet suit ce document à la lettre.

## Principes directeurs

1. **Moins de code = moins de bugs.** On supprime avant d'ajouter. Pas de code mort, pas de
   "au cas où", pas d'abstraction prématurée (règle de 3 : on n'abstrait qu'à la 3ᵉ répétition).
2. **Lisible > malin.** Le code concis ne doit jamais devenir cryptique. Un junior doit
   comprendre une fonction en < 30 s.
3. **Natif d'abord.** Aucune dépendance tierce sans justification écrite. La stdlib Swift +
   AppKit/SwiftUI couvrent 99 % des besoins. Exception tolérée : Sparkle (mises à jour).
4. **Léger par conception.** Tout code qui tourne au repos est suspect (cf. [07](07-architecture-technique.md)).
5. **Échouer proprement.** Une fonction qui dépend d'une API privée/permission se dégrade,
   ne plante jamais l'app.

---

## Langages & versions

| Élément | Choix |
|---|---|
| Langage | **Swift 5.10+** (ou la dernière stable), `swift-tools-version` figé dans le Package. |
| UI | **SwiftUI** pour le contenu, **AppKit** pour la fenêtre/encoche. |
| Concurrence | **`async/await` + `actor`** exclusivement. Pas de `DispatchQueue` manuel sauf cas bas niveau justifié. Pas de complétions par closures pour du nouveau code. |
| Cible | macOS 13.0 minimum. |
| Build | **Swift Package Manager** (pas de fichier `.xcodeproj` versionné si évitable ; sinon généré). |

---

## Structure du projet

Reprend le découpage de [07](07-architecture-technique.md). **Un type = un fichier.**
Le nom du fichier = le nom du type principal.

```
Sources/
  App/            Entrée, AppDelegate, agent, routing
  Core/
    NotchWindow/      Fenêtre + états repos/survol/ouvert
    NotchGeometry/    Détection dynamique de l'encoche
    ModuleKit/        Protocole NotchModule + registre
    Settings/         Store + fenêtre réglages
    Permissions/      Gestion centralisée
  Modules/
    Media/  Clipboard/  System/  Timer/
  Resources/      Assets, Localizable
Tests/
  CoreTests/  ModulesTests/
```

**Règles de dossier :**
- Un module = un dossier autonome, ne dépend QUE de `ModuleKit` et `Core`, **jamais** d'un autre module.
- Pas de dossier "Utils"/"Helpers" fourre-tout. Une extension vit à côté du type qu'elle étend
  (`String+Trimming.swift`), groupée par intention.

---

## Nommage

| Élément | Convention | Exemple |
|---|---|---|
| Types (struct/class/enum/protocol) | `UpperCamelCase` | `NotchWindow`, `MediaModule` |
| Propriétés, fonctions, variables | `lowerCamelCase` | `notchWidth`, `togglePlayback()` |
| Constantes globales / cas d'enum | `lowerCamelCase` | `.collapsed`, `.expanded` |
| Protocoles | nom = capacité, suffixe `-ing`/`-able` ou nom-rôle | `NotchModule`, `MediaSource` |
| Booléens | question | `isExpanded`, `hasNotch`, `shouldAutoPeek` |
| Fonctions = action | verbe | `expand()`, `loadArtwork()`, non `artwork()` |
| Fichiers | = type principal | `MediaModule.swift` |
| Extensions | `Type+Sujet.swift` | `NSScreen+Notch.swift` |

- Pas d'abréviations (`btn`, `cfg`, `mgr` → `button`, `config`, `manager`).
- Pas de préfixe de type hongrois ni de `_` privé (sauf backing store de propriété calculée).
- L'anglais pour le **code** (identifiants, commentaires techniques) et la doc interne ; les
  **textes affichés** ne sont jamais en dur — ils passent par la localisation (voir ci-dessous).

### Internationalisation — règle bloquante

L'app est multilingue dès le départ (cf. [doc 07 → i18n](07-architecture-technique.md#internationalisation-i18n)).

- **Aucun texte visible codé en dur.** Toute chaîne affichée passe par le **String Catalog**
  (`.xcstrings`) via `Text("clé")` / `String(localized:)`. Un littéral affiché = revue refusée.
- Clés de traduction **descriptives** et stables (`media.nowPlaying.empty`, pas `text1`).
- Formats (dates, nombres, durées) via `FormatStyle` localisés, jamais de format manuel.
- Direction de mise en page via `leading`/`trailing` (jamais `left`/`right`) → RTL gratuit.
- Langue par défaut = celle du Mac ; override possible via le `LocalizationStore` injecté.

---

## Style Swift (le cœur du "moins de lignes, qualité parfaite")

### Privilégier l'expression à l'instruction
```swift
// ✅ concis et clair
var label: String { isPlaying ? "Pause" : "Lecture" }

// ❌ verbeux
func label() -> String {
    if isPlaying { return "Pause" } else { return "Lecture" }
}
```

### `guard` pour les sorties anticipées, pas de pyramide d'`if`
```swift
guard let screen = NSScreen.withNotch else { return .fallback }
```

### Immutabilité par défaut : `let` partout, `var` seulement si réassigné.

### Types valeur par défaut : `struct`/`enum`. `class` uniquement si identité/référence
ou interop AppKit l'exige (`final class` alors, jamais d'héritage ouvert).

### `enum` pour les états finis (pas de booléens qui se contredisent)
```swift
enum NotchState { case collapsed, peeking, expanded }   // ✅
// ❌ var isPeeking; var isExpanded  → états impossibles représentables
```

### Optionnels : `if let`/`guard let` raccourci, jamais de force-unwrap (`!`)
en code de production. `!` toléré seulement dans les tests et les `@IBOutlet`/constantes
prouvées non-nil avec commentaire.

### Pas de `self.` superflu (sauf closures où requis ou levée d'ambiguïté).

### Closures : syntaxe trailing, `$0` pour les courtes, paramètres nommés dès que ça aide la lecture.

### Limiter la longueur
- Fonction : **≤ 30 lignes** idéalement, > 50 = on découpe.
- Fichier : > 400 lignes = signal de responsabilité mal découpée.
- Ligne : ≤ 120 colonnes.
- Niveau d'indentation : ≤ 3-4. Au-delà, extraire.

---

## SwiftUI

- **Petites vues composables.** Une `View` qui dépasse ~80 lignes de `body` se découpe en
  sous-vues ou `@ViewBuilder`.
- Extraire les valeurs magiques (tailles, durées) dans un namespace de constantes
  (`enum Layout { static let panelWidth: CGFloat = 580 }`), jamais de littéraux dispersés.
- État : `@State` (local), `@Binding` (descendant), `@Observable`/`@StateObject` (modèle).
  Préférer le macro **`@Observable`** (Observation framework) au vieux `ObservableObject`.
- Pas de logique métier dans le `body`. La vue affiche, le modèle décide.
- Animations via `withAnimation`/`.animation(_:value:)` — centraliser les courbes (spring de l'encoche) dans `Layout`/`Motion`.

---

## Architecture & dépendances

- **Le cœur ne connaît pas les modules ; les modules connaissent le cœur.** Dépendances
  dirigées vers `Core`/`ModuleKit` uniquement. Vérifiable : aucun `import` croisé entre modules.
- **Protocole avant implémentation** pour tout ce qui touche une API instable :
  `MediaSource`, `NotificationSource`, `Toggle` → l'app dépend du protocole, jamais du framework privé directement.
- **Injection de dépendances par initialiseur** (pas de singletons cachés). Un seul point
  de composition dans `App/`. `UserDefaults`/réglages passés en dépendance, pas accédés globalement.
- Pas d'état global mutable. Les réglages vivent dans un `@Observable` SettingsStore injecté.

---

## Concurrence

- Tout code touchant l'UI : `@MainActor`.
- Accès partagé mutable : `actor`.
- Pas de `Task { }` orphelin sans gestion d'annulation quand le cycle de vie l'exige.
- Aucune attente bloquante sur le main thread.

---

## Gestion des erreurs

- `throws` + `Result` pour les erreurs récupérables ; jamais d'erreur avalée en silence
  (au minimum un `log`).
- Erreurs typées par domaine (`enum MediaError: Error`).
- Aucune `fatalError` en production sauf invariant de programmation réellement impossible (documenté).

---

## Commentaires & documentation

- Le code se documente par ses noms. **Un commentaire explique le *pourquoi*, jamais le *quoi*.**
- Doc-comments `///` sur les API publiques de `ModuleKit` et `Core` (ce que d'autres consomment).
- `// TODO:` / `// FIXME:` autorisés mais avec contexte ; pas de commentaire mort/code commenté.
- Marquer les contournements d'API privée : `// PRIVATE API: MediaRemote — peut casser, voir doc 07`.

---

## Tests

- **Unitaires** sur la logique pure : `NotchGeometry` (détection), parsers (rappels), réducteurs d'état.
- On ne teste pas l'UI pixel ; on teste les **modèles** et la **logique de décision**.
- `@MainActor` pour les tests qui touchent l'UI. Préférer Swift Testing (`@Test`) si dispo, sinon XCTest.
- Pas de test qui dépend du réseau ou de l'horloge réelle (injecter le temps).

---

## Outillage (qualité automatique, zéro débat de style)

| Outil | Rôle |
|---|---|
| **swift-format** | Formatage canonique. Config versionnée. Lancé en pré-commit + CI. |
| **SwiftLint** | Règles de qualité (force-unwrap interdit, longueur de fonction, etc.). CI bloquante. |
| **CI** (GitHub Actions) | build + tests + lint sur chaque PR. |

Une PR ne passe pas si : ça ne compile pas, un test échoue, le lint râle, ou il reste un `print` de debug.

---

## Git

- Branches : `feat/…`, `fix/…`, `refactor/…`, `docs/…`.
- **Commits conventionnels** : `feat(media): scrubbing de la barre de progression`.
- PR petites et ciblées (un sujet). Description liant la doc concernée.
- `main` toujours buildable.

---

## Checklist de revue (avant tout merge)

- [ ] Aucune ligne superflue : pourrait-on faire plus court sans nuire à la lisibilité ?
- [ ] Aucun force-unwrap, aucun `print`, aucun code mort/commenté.
- [ ] Aucun texte affiché en dur : tout passe par le String Catalog (i18n).
- [ ] Noms explicites, fonctions courtes, un type par fichier.
- [ ] Modules sans dépendance croisée ; API privées derrière un protocole.
- [ ] Rien ne tourne au repos ; jauges arrêtées panneau fermé.
- [ ] Dégradation propre si permission/API absente.
- [ ] Constantes nommées, pas de littéraux magiques.
- [ ] Tests pour la logique pure ajoutée/modifiée.
- [ ] swift-format + SwiftLint passent.
