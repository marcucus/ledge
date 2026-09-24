# 07 — Architecture technique

> Le *comment*. Conçu pour rester léger et pour gérer proprement les 4 cas critiques.
> On y décrit les intentions et les choix, pas du code figé.

## Pile

| Couche | Techno | Pourquoi |
|---|---|---|
| Fenêtre encoche | **AppKit** (`NSWindow` borderless, non-activating, `.statusBar`/`.screenSaver` level) | Seul moyen de placer une UI au pixel près près de l'encoche et de la garder au-dessus. |
| Contenu / UI | **SwiftUI** (hébergé dans `NSHostingView`) | Rapide à construire, animations spring natives. |
| Cycle de vie | **Agent** (`LSUIElement = true`) | Pas d'icône Dock, démarrage léger. |
| Réglages | Fenêtre `NSWindow` classique + `@AppStorage`/`UserDefaults` | Standard macOS. |
| Données | Événements système (voir chaque module) | **Zéro polling** sauf presse-papiers (négligeable). |

## Pourquoi c'est léger (le vrai argument)

> « Langage léger » ≠ la seule clé. La clé est de **ne rien faire au repos.**

- **Pas de boucle de rafraîchissement globale.** Chaque module s'abonne à des notifications
  système et ne calcule que sur événement.
- Les **jauges** (CPU/RAM/réseau) ne tournent **que panneau ouvert**, puis s'arrêtent.
- Le **rendu** SwiftUI est suspendu quand le panneau est caché (vue non montée).
- **Pochettes / images** mises en cache.
- Binaire natif → **pas de runtime** (vs Electron ~150 Mo, Tauri WebView). Cible : ~10–20 Mo RAM au repos, ~0 % CPU.

Budget indicatif visé :
| État | RAM | CPU |
|---|---|---|
| Repos | 10–20 Mo | ~0 % |
| Panneau ouvert | 30–60 Mo | 1–4 % (pics au scrubbing/animation) |

## La fenêtre encoche

- `NSWindow` : `styleMask = .borderless`, `isOpaque = false`, fond transparent,
  `level` au-dessus de la barre de menu, `collectionBehavior` incluant
  `.canJoinAllSpaces` + `.fullScreenAuxiliary` (pour le cas plein écran).
- **Non-activating** (`.nonactivatingPanel`) → cliquer dedans ne vole pas le focus à l'app active
  (essentiel pour « coller dans l'app active », média, etc.).
- Positionnée via la géométrie réelle de l'écran (voir détection ci-dessous).

## Choix 4 — Détection dynamique de l'encoche (JAMAIS en dur)

Étapes :
1. `NSScreen.screens` → trouver l'écran à encoche.
2. `screen.safeAreaInsets.top` > 0 **et** `screen.auxiliaryTopLeftArea` /
   `auxiliaryTopRightArea` non nuls → l'écran a une encoche. La **largeur** de l'encoche se
   déduit de l'espace entre les deux zones auxiliaires ; la **hauteur** du `safeAreaInsets.top`.
3. On en tire un `CGRect` de l'encoche en coordonnées écran → on ancre la fenêtre dessous.
4. **Recalcul** sur `NSApplication.didChangeScreenParametersNotification` (changement de
   résolution, branchement d'écran, etc.).
5. **Fallback** : si non détecté (modèle inconnu, écran externe), on bascule sur la
   **pseudo-encoche** / le mode manuel des Paramètres. Aucune constante codée en dur :
   même le fallback a des valeurs par défaut *paramétrables*.

## Choix 1 — Multi-écran / écran sans encoche

- L'app observe `didChangeScreenParametersNotification` et le déplacement du curseur (si
  l'option « suivre le curseur » est active).
- Selon le réglage (cf. [Paramètres](06-ecran-parametres.md)) :
  - **Écran intégré** : fenêtre sur l'écran à encoche uniquement.
  - **Suivre le curseur / principal** : on repositionne la fenêtre sur l'écran cible ; s'il
    n'a pas d'encoche → **pseudo-encoche** rendue par l'app (un rectangle noir arrondi en haut centre).
  - **Tous les écrans** : une fenêtre par écran (coût mémoire un peu plus élevé → prévenir).

## Choix 2 — Plein écran

- En plein écran macOS masque la barre de menu et l'encoche est « avalée » par le contenu.
- `collectionBehavior` avec `.fullScreenAuxiliary` permet à notre panneau de coexister.
- Selon le réglage :
  - **Accessible au survol** : on n'affiche rien tant que le curseur ne touche pas le bord haut, façon barre de menu auto-hide.
  - **Masquer auto** : la fenêtre se cache complètement.
  - **Overlay permanent** : toujours visible par-dessus (utile pour timer/anneau).
- Détection via `NSWorkspace`/observation de l'app active en plein écran.

## Choix 3 — Permissions

Stratégie **paresseuse et contextuelle** (réglable) + récap dans Paramètres :

| Permission | Quand / Comment | Fragilité |
|---|---|---|
| Notifications | `UNUserNotificationCenter.requestAuthorization` à la 1re alerte | publique, stable |
| Presse-papiers | `NSPasteboard` — pas de prompt système | stable |
| Accessibilité | `AXIsProcessTrustedWithOptions` → ouvre Réglages si refus | nécessaire pour certains toggles |
| Automation (AppleScript) | prompt au 1er `osascript` ciblant une app | par-app |
| Notifs d'autres apps | lecture du store Notification Center | **fragile**, avancé, off par défaut |

Règles :
- Ne **jamais** demander une permission tant que la fonction qui la requiert n'est pas utilisée
  (sauf si l'utilisateur la pré-accorde via la page Permissions).
- Chaque fonction qui dépend d'une permission **se dégrade proprement** si refusée (se masque + explication).

## Internationalisation (i18n)

L'app est **multilingue dès le départ**. Règle de conception : **aucun texte visible codé en
dur** — toute chaîne affichée passe par la localisation.

**Comportement attendu :**
- **Au premier lancement** : Ledge suit la **langue du Mac** (`Locale.preferredLanguages` /
  les langues système). C'est le mode « Système », valeur par défaut.
- Un **sélecteur de langue** dans *Paramètres → Général* permet de **forcer** une langue
  précise, indépendamment du système (cf. [doc 06](06-ecran-parametres.md)).
- Le changement est **appliqué à chaud** : les vues SwiftUI se redessinent dans la nouvelle langue
  sans redémarrer l'app.

**Implémentation (intentions, pas de code figé) :**
- **String Catalogs** (`.xcstrings`, le format moderne) — un seul catalogue versionné, traductions
  par langue. Préférer à l'ancien `Localizable.strings` éparpillé.
- Accès via `String(localized:)` / la syntaxe SwiftUI `Text("clé")` ; **jamais** de littéral
  affiché directement.
- **Override de langue à chaud** : on ne se repose pas uniquement sur le `.lproj` choisi au
  lancement par le système. On expose la langue effective via un objet `@Observable`
  `LocalizationStore` injecté (cf. conventions) ; changer la langue met à jour un `Locale.Language`
  / `environment(\.locale)` racine → toutes les vues se relocalisent.
- Persistance du choix dans les réglages (`UserDefaults`), « Système » = pas d'override.
- Prévoir le **pluriel** (`.stringsdict` / variations du String Catalog) et les **formats
  localisés** (dates, nombres, temps des timers) via `Date.FormatStyle` / `Measurement`.
- **RTL** : ne pas coder en dur la direction ; laisser SwiftUI gérer l'alignement
  (`leading`/`trailing`, jamais `left`/`right`).

**Langues au démarrage (proposition) :** Français + English en V0, puis Español / Deutsch /
Italiano selon la demande. La clé est d'avoir **l'infrastructure** prête dès le départ ; ajouter
une langue = ajouter une colonne au catalogue, zéro changement de code.

> Conséquence sur les conventions : voir [doc 08](08-conventions-de-code.md) — « aucun texte
> visible en dur » devient une règle de revue bloquante.

## Frameworks privés — gestion du risque

`MediaRemote` (média) et la lecture du store de notifications sont **privés** → peuvent
casser à chaque màj macOS. Mitigation :
- Couche d'abstraction par module (`MediaSource`, `NotificationSource`) → on peut remplacer l'implémentation.
- Détection de version macOS + désactivation propre si l'API attendue manque.
- Ces fonctions sont **isolées** : leur panne ne doit jamais faire tomber le reste de l'app.

## Découpage en cibles / packages (proposition)

```
Ledge/
  App/                 → cycle de vie, agent, fenêtre encoche, routing modules
  Core/
    NotchWindow        → NSWindow + ancrage + états (repos/survol/ouvert)
    NotchGeometry      → détection dynamique de l'encoche + multi-écran
    ModuleKit          → protocole `NotchModule` (icône, vue aperçu, vue ouverte, réglages)
    Settings           → store + fenêtre réglages
    Permissions        → gestion centralisée + page récap
  Modules/
    MediaModule
    ClipboardModule
    SystemModule
    TimerModule
```

> `NotchModule` = le protocole qui rend les modules **pluggables** : chaque module fournit
> son icône d'onglet, sa vue d'aperçu (survol), sa vue complète (ouvert) et ses réglages.
> Ajouter un module futur = créer un nouveau type conforme, sans toucher au cœur.

## Distribution (à anticiper)

- **Hors Mac App Store** probablement nécessaire : les frameworks privés (MediaRemote) et
  certaines permissions (Accessibilité, lecture notifs) sont **incompatibles avec le sandbox MAS**.
- Donc : distribution directe (DMG), **signée + notarisée** par Apple pour passer Gatekeeper.
- Prévoir un mécanisme de mise à jour (Sparkle est le standard).
