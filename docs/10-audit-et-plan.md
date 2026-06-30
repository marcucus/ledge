# 10 — Audit & plan (chef de projet)

> Audit complet du code (qualité, features manquantes, sécurité, performance) + plan d'action.
> Établi le **2026-06-24**. À mettre à jour au fil des avancées.
>
> Légende gravité : 🔴 bloquant / important · 🟡 à traiter · 🟢 mineur / cosmétique.

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
| B6 | **Distribution** : Sparkle non configuré — `SUFeedURL` et `SUPublicEDKey` = placeholders dans [Info.plist](../Sources/App/Info.plist). | doc 09 | 🔴 (bloquant release) |

> Déjà présent (plus avancé que la doc 09 ne le dit) : AirDrop (`NSSharingServicePicker`), lanceur
> d'apps, notifications `UserNotifications`, launch-at-login (`SMAppService`), sélecteur de langue.

---

## C. Audit sécurité

| # | Constat | Détail | Gravité |
|---|---------|--------|---------|
| S1 | **Usage descriptions absentes de l'Info.plist** | Le code lance `osascript` (Automation/Apple Events) mais il **manque `NSAppleEventsUsageDescription`**. Sous Hardened Runtime + notarisation, la permission peut être refusée silencieusement → seek/pochette cassés sans message. | 🔴 |
| S2 | **Sparkle = placeholders** | Feed et clé EdDSA non renseignés. À configurer **avant** toute distribution. | 🔴 |
| S3 | `disable-library-validation = true` | Nécessaire pour `dlopen` MediaRemote/DisplayServices, donc justifié, mais affaiblit la validation. À documenter pour la notarisation. | 🟡 |
| S4 | **CGEventTap clavier global** (`.cghidEventTap`) | Surface puissante. Implémentation saine (ne logge/ne stocke rien, filtre sur codes média) — à ne jamais étendre sans revue. | 🟡 |
| S5 | Presse-papiers — filtrage partiel | Skip `ConcealedType` ✓, mais contenus sensibles non marqués restent en historique RAM. À mentionner dans la doc confidentialité. | 🟢 |
| S6 | Cosmétique légal | Copyright `© 2024` dans [Info.plist](../Sources/App/Info.plist) vs `© 2026` ailleurs. | 🟢 |

**Positifs** : AppleScript statique avec `Int(position)` → pas d'injection ; pochette Spotify en
HTTPS (`i.scdn.co`) ; absence de sandbox cohérente avec les frameworks privés.

---

## D. Audit performance

Principe README : « **on ne fait pas de polling** ». Réalité : **3 boucles de polling permanentes**.

| # | Constat | Impact | Reco |
|---|---------|--------|------|
| P1 | **[SystemObserver](../Sources/Modules/System/SystemObserver.swift) poll 0,2 s, en continu, activé par défaut** (`hudReplaceSystem = true`). 5 lectures/s CoreAudio + DisplayServices **H24, panneau fermé**. | Plus gros écart au principe de légèreté. | Poller seulement par fenêtre courte après un événement clavier, ou intervalle ~0,5 s, ou s'appuyer sur `.systemDefined` + Centre de contrôle. |
| P2 | **[MediaModule.resyncAppleMusicElapsed](../Sources/Modules/Media/MediaModule.swift) : `Process`/`osascript` forké toutes les 5 s** pendant lecture Apple Music. | Créer un process tous les 5 s ≫ une lecture mémoire. | Remplacer le spawn `osascript` par **ScriptingBridge** (`SBApplication`), in-process. |
| P3 | [MediaModule](../Sources/Modules/Media/MediaModule.swift) poll de secours **3 s en continu**, même sans lecture. | Léger mais permanent. | Suspendre quand aucun lecteur actif. |
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
| 0 | S2/B6 — Sparkle configuré | ✅ partiel — clé EdDSA générée (privée dans le Keychain, publique dans Info.plist) ; `make appcast` signe les `.dmg` et génère `dist/appcast.xml` via `generate_appcast`. ⏳ `SUFeedURL` reste un placeholder (`TODO-DOMAINE-LEDGE-SITE`) tant que le domaine n'est pas choisi. Le pipeline de stockage des `.dmg` côté `ledge-site` (R2/S3/Vercel Blob) n'est pas implémenté — cf. `PROMPT-SITE-WEB.md` §2bis. |
| 0 | S6 — copyright | ✅ `© 2026` |
| 0 | P1 — polling HUD | ✅ volume passé à un listener CoreAudio événementiel (`AudioObjectAddPropertyListenerBlock`, zéro polling) ; luminosité : zéro lecture en mode par défaut (`hudBrightnessManualOnly`), poll à 0,2 s seulement si l'utilisateur désactive ce mode ; sinon un battement à 2 s pour le seul recheck de la permission Accessibilité. |
| 1 | B1 — raccourcis personnalisables | ✅ `GlobalKeyboardShortcut` (Core, Codable, persisté en JSON dans `UserDefaults`) + `ShortcutRecorderView` (capture clavier locale, exige ≥1 modificateur) + `GlobalShortcutManager` lit désormais `SettingsStore` au lieu de coder les combinaisons en dur. |
| 1 | E2 — code mort launchAtLogin | ✅ propriété supprimée de `SettingsStore` (le toggle réel passe par `SMAppService`) |
| 1 | P2/P3 — ScriptingBridge + poll média | ✅ `AppleMusicScriptingBridge` (en-process, délégué anti-exception) remplace les 2 spawns `osascript` (seek + resync 5 s) ; le poll de secours média est borné à 3 tentatives au lancement puis s'arrête (zéro polling au repos). ⚠️ Seek/resync non vérifiés en conditions réelles (Apple Music en lecture) — à confirmer à l'usage. |
| 2 | E1 — tests | ✅ `SettingsStore` rendu injectable (`init(defaults:)`) pour permettre des tests isolés ; +18 tests (`NotchControllerTests` : priorités ambient, transitions HUD/expanded/clic ; `MediaStateMergeTests` : logique de merge extraite en fonction pure `MediaState.merging` ; `SystemObserverTests` : `decodeMediaKey`/`clamp`). 27 tests au total, tous verts. |
| 2 | B4 — pochette Apple Music | ✅ `AppleMusicScriptingBridge.currentArtwork()` (chaîne `currentTrack→artworks→data`, bridgée directement en `NSImage`) remplace l'export AppleScript vers fichier temporaire — plus robuste (zéro I/O disque intermédiaire). ⚠️ Non vérifié avec une lecture réelle (aucun morceau en cours sur la machine de dev). |
| 2 | B3 — persistance presse-papiers | ✅ `ClipboardHistoryStore` (JSON dans Application Support) + réglage `clipboardPersistEnabled` (**désactivé par défaut : RAM uniquement**, conforme à la confidentialité doc 03). Toggle dans Réglages → Presse-papiers ; désactiver l'option efface aussi le fichier sur disque. |
| 3 | Features F | ✅ Implémentées (via subagents en worktrees isolés) : presse-papiers (épingler + recherche), Drop Zone (drag-out + aperçu QuickLook), Système (indicateur micro, batterie accessoires Bluetooth), **profils de modules par app active** (`FrontmostAppObserver` + `AppProfile`), nouveaux modules **Raccourcis** (Shortcuts.app), **Calendrier** (EventKit), **Notes éphémères**, **thèmes nommés** (couleur + opacité + rayon en 1 clic). Doc d'extensibilité `NotchModule` → [doc 11](11-extensibilite-modules.md). **Descopés** (décision utilisateur / pas d'API publique fiable) : météo, sync iCloud, mode Focus, codes 2FA, AirDrop entrant, progression tâches longues, chargement dynamique de plugins tiers (doc-only pour raisons de sécurité). |
| 3 | E3 — alignement doc | ✅ README (« presque rien au repos » + statut « implémentation avancée ») et doc 09 (HUD natif/distribution à jour). |
| 3 | E4 — constantes géométrie | ✅ littéraux `190/32` centralisés dans `NotchGeometry.fallbackSize` (utilisé par `NotchController` et `NotchWindow`). |
| 3 | E5 — CLAUDE.md | ✅ `PROMPT_IA.md` (obsolète) remplacé par un `CLAUDE.md` racine (commandes, conventions, pièges permissions/bundle/instance unique, extensibilité). |
| — | UI/UX (session) | ✅ Timer redessiné (molette H:M:S + démarrage immédiat, 2 colonnes réglage/timers actifs, ambient décompte live) ; NavBar (icônes blanches, modules répartis autour de l'encoche, batterie/réglages à droite) ; module Système masqué (onglet retiré, batterie conservée) ; icône Dock au gabarit macOS quand Réglages ouverts ; signature dev stable (Accessibilité persistante). |
