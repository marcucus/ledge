# 10 — Audit historique & suivi

> Audit initial établi le **24 juin 2026**, conservé pour expliquer les décisions prises.
> Il ne constitue plus la liste des travaux restants.
>
> Légende gravité : 🔴 bloquant / important · 🟡 à traiter · 🟢 mineur / cosmétique.

## État courant au 30 septembre 2026

- Les jalons historiques 0 à 3 et les jalons de finalisation 1 à 4 sont terminés.
- L'application compte huit modules compilés, sept onglets visibles et 75 tests dans 10 suites.
- La version publique est `0.2.0`. La candidate locale est `0.3.0` (build `3`).
- Le plan actif est désormais le **jalon 5** de [l'audit de finalisation](13-audit-finalisation.md) :
  CI, recette manuelle, second Mac, mise à jour Sparkle et publication.
- Les routes juridiques et de distribution de `ledge-site` sont maintenant déployées et répondent
  correctement. La CI de l'app reste à valider après commit sur GitHub.
- Les constats ci-dessous décrivent l'état au moment de l'audit initial. Le tableau **Suivi** indique
  leur résolution ; le code et les docs 09, 12 et 13 priment en cas de contradiction.

---

## A. Verdict qualité

Le code est **nettement au-dessus de la moyenne** et applique réellement la [doc 08](08-conventions-de-code.md) :

- **0** `fatalError`, **0** `try!`, **0** force-unwrap `!`, **0** `print`/`NSLog` traînant.
- Architecture modulaire propre : `Core` + 5 modules cloisonnés (aucune dépendance croisée),
  API privées derrière protocole ([MediaSource](../Sources/Modules/Media/MediaSource.swift)).
- Concurrence correcte (`@MainActor`, `@Observable`, continuations), dégradation propre partout.
- Vie privée presse-papiers : skip du `org.nspasteboard.ConcealedType` (gestionnaires de mots de
  passe), historique **en RAM uniquement**.

**Bémol global** : ~7000 lignes pour **67 lignes de tests** (uniquement `NotchGeometry`). Le prompt
fondateur exige « tout passe les tests » — c'est le point le plus en décalage avec la constitution.

---

## B. Features manquantes (specs prévues, non livrées)

| # | Manque | Source | Gravité |
|---|--------|--------|---------|
| B1 | **Raccourcis non personnalisables** : [GlobalShortcutManager](../Sources/App/GlobalShortcutManager.swift) câble en dur ⌥Espace/⌥V/⌥T/⌥M. La page Réglages laisse croire le contraire → UI trompeuse. | doc 06 | 🔴 |
| B2 | **Agrégation des notifications système** (onglet Notifs du module Timer). | doc 05 | 🟡 (pas d'API publique — à arbitrer) |
| B3 | **Persistance du presse-papiers** entre sessions (perdu au quit ; aucune option d'opt-in). | doc 03 | 🟡 |
| B4 | **Pochette Apple Music fiable** (toujours partielle via AppleScript). | doc 09 | 🟡 |
| B5 | **Détail batterie complet** : cycles / santé / temps restant promis par le wireframe. À confirmer. | doc 04 | 🟢 |
| B6 | **Distribution** : résolu côté code — clé Sparkle réelle, feed injecté au build et publication gratuite via GitHub Releases, sans compte Apple. | doc 09 | ✅ |

> Déjà présent (plus avancé que la doc 09 ne le dit) : AirDrop (`NSSharingServicePicker`), lanceur
> d'apps, notifications `UserNotifications`, launch-at-login (`SMAppService`), sélecteur de langue.

---

## C. Audit sécurité

| # | Constat | Détail | Gravité |
|---|---------|--------|---------|
| S1 | **Usage descriptions absentes de l'Info.plist** | Le code lance `osascript` (Automation/Apple Events) mais il **manque `NSAppleEventsUsageDescription`**. Sous Hardened Runtime + notarisation, la permission peut être refusée silencieusement → seek/pochette cassés sans message. | 🔴 |
| S2 | **Sparkle** | Résolu : clé EdDSA réelle dans le bundle et feed injecté par `make release`. | ✅ |
| S3 | `disable-library-validation = true` | Nécessaire pour `dlopen` MediaRemote/DisplayServices, donc justifié, mais affaiblit la validation. À documenter pour la notarisation. | 🟡 |
| S4 | **CGEventTap clavier global** (`.cghidEventTap`) | Surface puissante. Implémentation saine (ne logge/ne stocke rien, filtre sur codes média) — à ne jamais étendre sans revue. | 🟡 |
| S5 | Presse-papiers — filtrage partiel | Skip `ConcealedType` ✓, mais contenus sensibles non marqués restent en historique RAM. À mentionner dans la doc confidentialité. | 🟢 |
| S6 | Cosmétique légal | Copyright `© 2024` dans [Info.plist](../Sources/App/Info.plist) vs `© 2026` ailleurs. | 🟢 |

**Positifs** : AppleScript statique avec `Int(position)` → pas d'injection ; pochette Spotify en
HTTPS (`i.scdn.co`) ; absence de sandbox cohérente avec les frameworks privés.

---

## D. Audit performance

Principe actuel : **presque rien au repos**. Les anciens pollings permanents du HUD et du média
ont été supprimés ; le presse-papiers conserve la seule lecture périodique permanente, légère et
justifiée par l'absence d'événement système public équivalent.

| # | Constat | Impact | Reco |
|---|---------|--------|------|
| P1 | [SystemObserver](../Sources/Modules/System/SystemObserver.swift) : volume CoreAudio événementiel ; luminosité sans polling dans le mode par défaut. | ✅ Résolu. Le suivi à 0,2 s n'existe que si l'utilisateur désactive « clavier uniquement ». La permission Accessibilité est revue au changement d'app. | Conserver ce comportement. |
| P2 | Resynchronisation Apple Music via ScriptingBridge, sans création répétée de processus. | ✅ Résolu. | Valider avec une lecture réelle. |
| P3 | Poll de secours média limité à trois tentatives au lancement ; suivi 1 s/5 s uniquement pendant une lecture active. | ✅ Résolu au repos. | Conserver l'arrêt immédiat hors lecture. |
| P4 | [ClipboardSource](../Sources/Modules/Clipboard/ClipboardSource.swift) poll 0,8 s (lecture d'un `Int`). | Négligeable, justifié. | OK. |
| P5 | Monitor global `.leftMouseDragged` permanent (détection drag fichier). | Callback à chaque drag. | Acceptable ; éventuellement n'armer qu'au besoin. |

**Déjà optimisé** : `dominantColor` recalculée seulement au changement de pochette ; `visibleModules`
paresseux ; animations factorisées.

---

## E. Améliorations (dette / robustesse, sans nouvelle feature)

1. **Tests** : couvrir [NotchController](../Sources/Core/NotchWindow/NotchController.swift)
   (priorités ambient, transitions HUD↔ambient↔expanded), décodage touches média, merge `MediaState`.
2. **Code mort** : `SettingsStore.launchAtLogin` est écrit mais jamais lu (le toggle réel utilise
   `SMAppService.mainApp.status`). À supprimer.
3. **Aligner README/doc** : nuancer « zéro polling » (P1–P3) ; passer le statut README
   (« Conception ») et la doc 09 à « implémentation avancée ».
4. **Centraliser les littéraux** de geometry dupliqués (`notchW: 190 / notchH: 32` dans
   [NotchWindow](../Sources/Core/NotchWindow/NotchWindow.swift) et
   [NotchController](../Sources/Core/NotchWindow/NotchController.swift)).
5. **Convertir PROMPT_IA.md** en `CLAUDE.md` (le bloc « premier message attendu » est obsolète).

---

## F. Nouvelles fonctionnalités (idées)

**Quick wins (fort effet, faible coût)**
- **Calendrier / prochain événement** dans l'ambient (EventKit) : « Réunion dans 12 min ».
- **Épingler un item du presse-papiers** (favoris hors trim) + recherche dans l'historique.
- **Glisser-déposer *depuis* la Drop Zone** vers une autre app (sortie, pas que l'entrée).
- **Aperçu QuickLook** d'un fichier de la Drop Zone au survol.
- **Mute micro / caméra en appel** comme toggle + indicateur de confidentialité.

**Différenciants (signature produit)**
- **Indicateur d'enregistrement écran/micro** façon « Now Recording ».
- **Progression de tâches longues** (Time Machine, AirDrop, copie Finder) dans l'anneau.
- **AirDrop entrant** affiché dans l'encoche (réception animée).
- **Mode Focus** : apparence/modules synchronisés avec le Focus macOS actif.
- **Profils par app active** : modules différents selon l'app au premier plan.

**Modules entièrement nouveaux**
- **Batterie d'accessoires** (AirPods, souris, clavier — `IOBluetooth`) / Météo.
- **Module Raccourcis (Shortcuts.app)** : lancer un raccourci depuis l'encoche.
- **Notes éphémères / codes 2FA** sous l'encoche.

**Plateforme / écosystème**
- **SDK de plugin** documenté (`NotchModule` est déjà un bon contrat).
- **Sync iCloud** des réglages (KVS).
- **Thèmes** et formes d'encoche alternatives.

---

## G. Plan d'action

Chaque ligne = une PR (règle « une tâche = un sujet = une PR »).

### Jalon 0 — Débloquer la release (priorité 1)
1. **S1** — ajouter `NSAppleEventsUsageDescription` (+ vérifier les autres `NS...UsageDescription`) à l'Info.plist.
2. **S2 / B6** — configurer Sparkle réel (feed HTTPS + clé EdDSA), retirer les placeholders.
3. **S6** — corriger le copyright.
4. **P1** — revoir le polling 0,2 s du HUD (défaut activé → visible en conso pour tout le monde).

### Jalon 1 — Combler les promesses de l'UI
5. **B1** — raccourcis réellement personnalisables (capture + persistance), sinon retirer la page.
6. **E2** — supprimer le code mort `launchAtLogin`.
7. **P2 / P3** — ScriptingBridge pour Apple Music + suspension du poll média au repos.

### Jalon 2 — Robustesse
8. **E1** — tests `NotchController` + décodage média + merge `MediaState`.
9. **B4** — fiabiliser la pochette Apple Music (ScriptingBridge / iTunesLibrary).
10. **B3** — option persistance presse-papiers (opt-in, RAM par défaut).

### Jalon 3 — Croissance produit
11. Choisir 2–3 features de la section F (reco : Calendrier/EventKit, épinglage presse-papiers, batterie accessoires).
12. **E3 / E4 / E5** — aligner la doc (README/09), centraliser les constantes de géométrie, convertir PROMPT_IA → CLAUDE.md.

---

## Suivi

| Jalon | Item | État |
|---|---|---|
| 0 | S1 — usage descriptions Info.plist | ✅ `NSAppleEventsUsageDescription` ajouté (en/fr via `InfoPlist.strings`, copié par le Makefile à la racine du bundle) |
| 0 | S2/B6 — Sparkle configuré | ✅ clé EdDSA dans Info.plist ; `make release` construit un DMG ad hoc sans compte Apple, génère l'appcast signé et publie les deux assets dans une GitHub Release. Le token fin `Contents: write`, limité à `marcucus/ledge`, est conservé dans le Trousseau macOS. `make release-notarized` conserve un parcours Apple optionnel. |
| 0 | S6 — copyright | ✅ `© 2026` |
| 0 | P1 — polling HUD | ✅ volume passé à un listener CoreAudio événementiel (`AudioObjectAddPropertyListenerBlock`, zéro polling) ; luminosité : zéro lecture en mode par défaut (`hudBrightnessManualOnly`), poll à 0,2 s seulement si l'utilisateur désactive ce mode ; recheck de la permission Accessibilité au changement d'application, sans battement au repos. |
| 1 | B1 — raccourcis personnalisables | ✅ `GlobalKeyboardShortcut` (Core, Codable, persisté en JSON dans `UserDefaults`) + `ShortcutRecorderView` (capture clavier locale, exige ≥1 modificateur) + `GlobalShortcutManager` lit désormais `SettingsStore` au lieu de coder les combinaisons en dur. |
| 1 | E2 — code mort launchAtLogin | ✅ propriété supprimée de `SettingsStore` (le toggle réel passe par `SMAppService`) |
| 1 | P2/P3 — ScriptingBridge + poll média | ✅ `AppleMusicScriptingBridge` (en-process, délégué anti-exception) remplace les 2 spawns `osascript` (seek + resync 5 s) ; le poll de secours média est borné à 3 tentatives au lancement puis s'arrête (zéro polling au repos). ⚠️ Seek/resync non vérifiés en conditions réelles (Apple Music en lecture) — à confirmer à l'usage. |
| 2 | E1 — tests | ✅ `SettingsStore` rendu injectable (`init(defaults:)`) pour permettre des tests isolés ; couverture de la géométrie des compositions, de la persistance de leur navigation et du maintien ouvert pendant le popover incluse. La passe de robustesse ajoute timers après veille, grille vide, module sélectionné puis masqué, ordre des épinglés et fichier de Drop Zone supprimé. La suite atteint maintenant 75 tests dans 10 suites. |
| 2 | B4 — pochette Apple Music | ✅ `AppleMusicScriptingBridge.currentArtwork()` (chaîne `currentTrack→artworks→data`, bridgée directement en `NSImage`) remplace l'export AppleScript vers fichier temporaire — plus robuste (zéro I/O disque intermédiaire). ⚠️ Non vérifié avec une lecture réelle (aucun morceau en cours sur la machine de dev). |
| 2 | B3 — persistance presse-papiers | ✅ `ClipboardHistoryStore` (JSON dans Application Support) + réglage `clipboardPersistEnabled` (**désactivé par défaut : RAM uniquement**, conforme à la confidentialité doc 03). Toggle dans Réglages → Presse-papiers ; désactiver l'option efface aussi le fichier sur disque. |
| 3 | Features F | ✅ Implémentées (via subagents en worktrees isolés) : presse-papiers (épingler + recherche), Drop Zone (drag-out + aperçu QuickLook), Système (indicateur micro, batterie accessoires Bluetooth), **profils de modules par app active** (`FrontmostAppObserver` + `AppProfile`), nouveaux modules **Raccourcis** (Shortcuts.app), **Calendrier** (EventKit), **Notes éphémères**, **thèmes nommés** (couleur + opacité + rayon en 1 clic). Doc d'extensibilité `NotchModule` → [doc 11](11-extensibilite-modules.md). **Descopés** (décision utilisateur / pas d'API publique fiable) : météo, sync iCloud, mode Focus, codes 2FA, AirDrop entrant, progression tâches longues, chargement dynamique de plugins tiers (doc-only pour raisons de sécurité). |
| 3 | E3 — alignement doc | ✅ README (« presque rien au repos » + statut « implémentation avancée ») et doc 09 (HUD natif/distribution à jour). |
| 3 | E4 — constantes géométrie | ✅ littéraux `190/32` centralisés dans `NotchGeometry.fallbackSize` (utilisé par `NotchController` et `NotchWindow`). |
| 3 | E5 — CLAUDE.md | ✅ `PROMPT_IA.md` (obsolète) remplacé par un `CLAUDE.md` racine (commandes, conventions, pièges permissions/bundle/instance unique, extensibilité). |
| — | UI/UX (session) | ✅ Timer redessiné (molette H:M:S + démarrage immédiat, 2 colonnes réglage/timers actifs, ambient décompte live) ; NavBar noire continue avec l'encoche, lanceur de modules en grille redessiné et trois dispositions persistantes (Concentrée, Panoramique recommandée, Immersive) ; chaque disposition mémorise le placement exclusif Barre/Grille/Masqué de chaque module et la visibilité du bouton de grille ; Média adapte réellement sa composition intérieure à chaque disposition ; ambient conserve une silhouette commune ; ouverture séquencée surface/contenu, masque appliqué à toute la hiérarchie et silhouette bornée pendant le redimensionnement ; en-tête des Réglages intégré au flux, sans recouvrir la première section ; module Système masqué (onglet retiré, batterie conservée) ; icône Dock au gabarit macOS quand Réglages ouverts ; onboarding éditorial en 3 étapes ; permissions centralisées avec états réels et demande contextuelle ; états vides harmonisés ; VoiceOver et réduction des animations pris en charge ; choix persistant de l'écran cible avec pseudo-encoche externe et fallback de déconnexion ; signature dev stable (Accessibilité persistante). |
| — | Jalon 1 de finalisation | ✅ Ouverture directe au survol conservée et testée ; fermeture Échap + clic extérieur local/global ; zone de survol configurable ; détection événementielle du plein écran avec politiques Accessible/Masqué/Overlay ; anneau de timer converti en progression réelle sans boucle d'animation continue. |
| — | Jalon 2 de finalisation | ✅ `NotchController` relie réellement `enabled` (réglages globaux + profil d'app actif) au cycle `start()`/`stop()` des modules — un module désactivé est effectivement arrêté, pas seulement masqué de la navigation ; conséquence directe pour la confidentialité, le presse-papiers désactivé (globalement ou par profil d'app) ne capture plus rien. Module Système retiré du catalogue des Réglages → Modules (décision produit : garder masqué plutôt que réintégrer l'onglet, réglages trompeurs supprimés). Erreurs de persistance du presse-papiers (lecture/écriture/suppression) visibles et récupérables via `SettingsStore.clipboardPersistenceIssue` + bouton « Réessayer ». Build, 75 tests et SwiftLint ont ensuite été validés. |
| — | Jalon 3 de finalisation | ✅ Ancrage du partage Drop Zone corrigé via `ViewAnchorReader` (capture le vrai `NSView` malgré le panel non-activating) ; collisions de noms de fichiers résolues à la copie (`DropZoneModule.uniqueDestination`, suffixe façon Finder). Identité de source média explicite (`MediaSourceIdentity`) remplaçant deux booléens qui pouvaient diriger une commande (ex. seek) vers le mauvais lecteur avec Apple Music et Spotify ouverts en même temps ; test manuel simultané documenté dans [doc 12](12-recette-release-candidate.md). Historique du presse-papiers chiffré (AES-GCM, clé Keychain via `ClipboardHistoryKeyStore`) avec migration transparente de l'ancien fichier en clair, exclusions d'apps par bundle identifier et collage en texte brut (⌘+clic). Timers actifs persistés entre lancements (`TimerPersistenceStore`) et peek configurable en fin de minuteur (option + durée). |
| — | Jalon 4 de finalisation | ✅ Progression média exposée comme slider VoiceOver ajustable (±15 s) ; molettes H:M:S du Timer dotées d'actions d'accessibilité ajustables avec bornes min/max ; état on/off du module Système exposé à l'accessibilité (`ToggleButton`, actuellement du code mort documenté — onglet retiré au Jalon 2). Quick Look de la Drop Zone utilisable au clavier (Espace, en plus du survol) et via une action VoiceOver nommée. « Système » localisé dans le sélecteur de langue (clé dédiée au lieu d'un littéral anglais). Échecs d'enregistrement du lancement à la connexion (`SMAppService`) affichés au lieu d'être avalés par `try?`. Nouvelle option « Réinitialiser tous les réglages » (Réglages → À propos, avec confirmation) : `SettingsStore.resetToDefaults()` supprime les clés `UserDefaults` puis recharge les valeurs par défaut via une instance jetable, pour ne pas dupliquer la cinquantaine de valeurs par défaut de `init(defaults:)`. ⚠️ `SettingsStore.swift` et `NotchController.swift` (429 lignes chacun) dépassent le seuil d'avertissement SwiftLint de 400 lignes (pas l'erreur à 500) ; restructuration délibérément reportée plutôt que refactorée sans pouvoir compiler. `Tests/CoreTests/NotchControllerTests.swift` (425 lignes) n'est pas concerné : `.swiftlint.yml` scope l'analyse à `included: Sources`, qui prime sur les répertoires passés à la CLI. `swift build && swift test && swiftlint lint --quiet Sources Tests` ont été exécutés par Adrien après un premier aller-retour (deux bugs de niveau d'accès et un avertissement de longueur de fonction dans `AppDelegate` corrigés en retour) : build ✅, 75 tests dans 10 suites ✅, SwiftLint sans erreur — Jalons 3 et 4 clos. |
