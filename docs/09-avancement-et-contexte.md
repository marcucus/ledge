# 09 — Avancement & contexte du projet

> Le *où on en est*. Les docs 01–08 décrivent la **vision** ; celui-ci décrit l'**état réel
> du code** à un instant donné. À mettre à jour au fil des avancées.
>
> Dernière mise à jour : **2026-09-30**

## Vue d'ensemble

Ledge est passé de la phase **conception** (docs 01–08) à une phase **implémentation
active**. Le socle technique (V0) et le premier module riche (Média, V1) sont en place, et les
huit modules existent au moins en version fonctionnelle. Le travail récent porte sur le
**polissage** (média, alignement de la NavBar) et sur une **nouvelle fonctionnalité système** :
le HUD volume/luminosité maison qui remplace celui de macOS.

Le 29 septembre 2026, les informations juridiques ont également été reliées au produit : la page
À propos et la dernière étape de l'onboarding ouvrent les mentions légales, la politique de
confidentialité, les conditions d'utilisation et les licences tierces publiées par `ledge-site`.
Le bundle construit par `make app` inclut désormais la licence complète de Sparkle. Ledge reste
gratuit et publié par Adrien Marques en personne physique, à titre non professionnel.

| Phase roadmap | État | Détail |
|---|---|---|
| **V0** — Fenêtre + 5 états + animation | ✅ Fait | Fenêtre ancrée, machine à états, hot zone, détection dynamique de l'encoche. |
| **V1** — Module Média | ✅ Fonctionnel | Lecture, contrôles, pochette (partiel), barre de progression scrubbable. |
| **V2** — Timers + Drop Zone | ✅ Présent | Modules implémentés. |
| **V3** — Presse-papiers + Système | ✅ Présent | Modules implémentés + HUD volume/luminosité (nouveau). |
| **V4** — Paramètres complets | ✅ Fait | Réglages multi-sections, onboarding, permissions centralisées, i18n, accessibilité et réinitialisation complète. |

## Pile technique réelle

Conforme à la [doc 07](07-architecture-technique.md), avec quelques précisions issues du code :

- **Swift Package Manager** (pas de projet Xcode). `swift-tools-version: 5.10`, cible
  **macOS 14+**, localisation par défaut `en`.
- Découpage en cibles : `App` (exécutable) → `Core` + 8 modules (`MediaModule`, `TimerModule`,
  `DropZoneModule`, `ClipboardModule`, `SystemModule`, `ShortcutsModule`, `CalendarModule`,
  `NotesModule`).
- **AppKit** (`NSPanel` borderless non-activating) pour la fenêtre encoche + **SwiftUI**
  (`NSHostingView`) pour le contenu.
- `SystemModule` lie **IOKit** et **CoreAudio** (`linkerSettings` dans [Package.swift](../Package.swift)).
- Frameworks privés via `dlopen`/`dlsym` : **MediaRemote** (média), **DisplayServices**
  (luminosité sur Apple Silicon).
- Build rapide : `swift build` / `swift test`. Les permissions se testent avec `make app`; la
  distribution directe passe par un DMG signé ad hoc et un appcast signé avec Sparkle EdDSA.

## Architecture du cœur (`Core`)

| Élément | Fichier | Rôle |
|---|---|---|
| Fenêtre encoche | [NotchWindow.swift](../Sources/Core/NotchWindow/NotchWindow.swift) | `NSPanel`, ancrage, frames par état, hot zone (tracking area), monitors de clic/drag global. |
| Machine à états | [NotchController.swift](../Sources/Core/NotchWindow/NotchController.swift) | `@Observable`, transitions, gestion du survol, du drag de fichiers et du HUD. |
| États | [NotchState.swift](../Sources/Core/NotchWindow/NotchState.swift) | `collapsed` · `ambient` · `peeking` · `hud` · `expanded`. |
| Contenu racine | [NotchContentView.swift](../Sources/Core/NotchWindow/NotchContentView.swift) | Aiguille NavBar / HUDBar / module selon l'état. |
| Forme | [NotchPanelShape.swift](../Sources/Core/NotchWindow/NotchPanelShape.swift) | Tracé arrondi du panneau (oreilles + rayon bas). |
| Géométrie | [NotchGeometry/](../Sources/Core/NotchGeometry/) | Détection dynamique de l'encoche (`safeAreaInsets`, zones auxiliaires). |
| Protocole module | [NotchModule.swift](../Sources/Core/ModuleKit/NotchModule.swift) | Contrat pluggable : icône d'onglet, vue aperçu, vue complète. |
| HUD | [HUDContent.swift](../Sources/Core/HUDContent.swift) | Struct publique (kind volume/luminosité, valeur 0–1, mute, teinte). |
| Réglages | [Core/Settings/](../Sources/Core/Settings/) | `SettingsStore` + enums. |
| i18n | [Localization.swift](../Sources/Core/Localization.swift) | Bundle de localisation + override de langue à chaud. |

### Les états de l'encoche

- **collapsed** — au repos, rendu à la taille de l'encoche et zone de survol invisible configurable.
- **ambient** — extension latérale discrète pour musique, timer ou Drop Zone.
- **peeking** — aperçu compact (largeur expanded, hauteur NavBar).
- **hud** — barre compacte volume/luminosité : fenêtre qui **entoure l'encoche**
  (`notchWidth + 170` de large, `notchHeight + 34` de haut), barre fine centrée **sous**
  l'encoche. Auto-dismiss après 1,6 s.
- **expanded** — panneau complet : 580 px en Concentrée, 920 px en Panoramique et 744 px en
  Immersive, avec une hauteur adaptée à chaque composition.

Le survol passe directement de `collapsed` ou `ambient` à `expanded`. `peeking` reste disponible
comme comportement explicite au clic ; ce n'est pas une étape automatique.

### Robustesse des interactions centrales (27 septembre 2026)

- fermeture du panneau par Échap, clic dans une autre app ou clic dans une autre fenêtre de Ledge ;
- zone de survol Précise, Standard ou Large, sans polling global de la souris ;
- détection événementielle du plein écran et application des modes Accessible, Masqué et Overlay ;
- suppression de l'ambient et du HUD en plein écran hors Overlay ;
- anneau de timer fondé sur la progression réelle, mis à jour par le tick du timer sans animation
  continue à haute fréquence.

## État par module

| Module | Fichiers clés | État | Notes |
|---|---|---|---|
| 🎵 **Média** | [MediaModule](../Sources/Modules/Media/MediaModule.swift), [MediaRemoteSource](../Sources/Modules/Media/MediaRemoteSource.swift), [MediaContentView](../Sources/Modules/Media/MediaContentView.swift) | ✅ Fonctionnel | Titre/artiste/album, play-pause/préc./suiv., timer écoulé, **barre scrubbable**. Pochette partielle (voir limites). |
| ⏱️ **Timers** | [TimerModule](../Sources/Modules/Timer/TimerModule.swift), [TimerContentView](../Sources/Modules/Timer/TimerContentView.swift) | ✅ Présent | Minuteurs/Pomodoro, anneau, notifications. |
| 📁 **Drop Zone** | [DropZoneModule](../Sources/Modules/DropZone/DropZoneModule.swift) | ✅ Présent | Étagère de fichiers ; ouverture auto au drag de fichiers près de l'encoche. |
| 📋 **Presse-papiers** | [ClipboardModule](../Sources/Modules/Clipboard/ClipboardModule.swift) | ✅ Présent | Historique de copies (seul polling toléré). |
| ⚙️ **Système** | [SystemModule](../Sources/Modules/System/SystemModule.swift), [SystemObserver](../Sources/Modules/System/SystemObserver.swift) | ✅ Source transverse | Batterie et HUD actifs ; onglet volontairement masqué de la navigation. |
| ⚡ **Raccourcis** | [ShortcutsModule](../Sources/Modules/Shortcuts/ShortcutsModule.swift) | ✅ Présent | Liste et lancement des raccourcis Shortcuts avec erreurs visibles. |
| 📅 **Calendrier** | [CalendarModule](../Sources/Modules/Calendar/CalendarModule.swift) | ✅ Présent | Prochain événement, permission contextuelle et polling arrêté sans autorisation. |
| 📝 **Notes** | [NotesModule](../Sources/Modules/Notes/NotesModule.swift) | ✅ Présent | Note locale simple persistée dans les préférences. |

## Focus : le HUD volume / luminosité (travail récent)

Nouvelle brique dans `SystemModule`, indépendante des jauges.

**Objectif** : afficher la barre maison de Ledge quand on change le volume ou la luminosité,
et **remplacer** l'overlay natif de macOS.

**Composants**
- [SystemObserver.swift](../Sources/Modules/System/SystemObserver.swift) — détection et contrôle bas niveau :
  - **Volume** via CoreAudio (`kAudioDevicePropertyVolumeScalar` / `…Mute`), lecture + écriture.
  - **Luminosité** via **DisplayServices** (`DisplayServicesGet/SetBrightness`) sur Apple Silicon,
    fallback IOKit (`IODisplayGetFloatParameter`) sur Intel.
  - **Volume événementiel** via les listeners CoreAudio, sans polling.
  - **Luminosité** : aucune lecture périodique avec le réglage par défaut « clavier uniquement » ;
    polling 0,2 s uniquement si l'utilisateur demande explicitement de suivre aussi les
    changements externes.
  - **Monitor clavier** `.systemDefined` immédiat pour la réactivité.
  - **CGEventTap** (`.cghidEventTap`) : intercepte les touches média, **consomme** l'événement
    (→ pas de HUD macOS) et applique lui-même le changement (pas de 1/16, ou 1/64 en mode fin
    Maj+Option). Nécessite la permission **Accessibilité**.
- [HUDContent.swift](../Sources/Core/HUDContent.swift) + `HUDBar` dans
  [NotchContentView.swift](../Sources/Core/NotchWindow/NotchContentView.swift) — la barre fine
  sous l'encoche, sans icône.
- `NotchController.showHUD()` — transition vers l'état `.hud`, auto-dismiss.
- Réglage **« Remplacer le HUD volume/luminosité macOS »** dans
  [GeneralSettingsView.swift](../Sources/App/Settings/GeneralSettingsView.swift)
  (`@AppStorage("hudReplaceSystem")`, **activé par défaut** via `register(defaults:)`).

**Comportement**
- Réglage **activé** (défaut) : la barre Ledge s'affiche via les événements système ; le HUD
  macOS est supprimé **dès que l'Accessibilité est accordée**. Le retour de Réglages Système est
  détecté au changement d'application, sans battement périodique au repos.
- Réglage **désactivé** : comportement macOS natif, Ledge ne montre rien.

## Limites connues / points ouverts

| Sujet | État | Détail |
|---|---|---|
| **Pochette d'album** | ⚠️ Partiel | MediaRemote est bloqué pour Apple Music sur macOS 15 (run non-bundlé) ; la notification distribuée `com.apple.Music.playerInfo` ne fournit pas d'image. Piste : `iTunesLibrary` via « Persistent ID ». |
| **Seek Apple Music** | ✅ Contourné | MediaRemote bloqué → on passe par **ScriptingBridge** (`set player position`) pour Music, MediaRemote (`MRMediaRemoteSetElapsedTime`) pour les autres lecteurs. Demande la permission **Automation** au 1er usage. |
| **Suppression HUD natif** | ✅ OK (bundle signé) | Le `CGEventTap` consomme les touches volume/luminosité **si l'Accessibilité est accordée**. Tester via `dist/Ledge.app` (`make app`), pas `swift run` (pas de bundle = pas de permission). `make app` signe avec une identité Apple Development **stable** → l'autorisation persiste entre les rebuilds. La barre Ledge (volume événementiel) marche sans permission. |
| **Distribution** | ✅ Code prêt | `make release` crée un bundle ad hoc et un DMG sans compte Apple, signe la mise à jour avec Sparkle EdDSA puis publie le DMG et l'appcast dans GitHub Releases. Gatekeeper impose une autorisation manuelle au premier lancement. |

## Permissions requises (récapitulatif)

| Permission | Pour quoi | Quand |
|---|---|---|
| **Accessibilité** | `CGEventTap` (supprimer le HUD natif volume/luminosité) | Prompt au lancement si le réglage HUD est actif. |
| **Automation (Music)** | Seek dans Apple Music via AppleScript | Prompt au 1er glissement sur la barre. |
| **Notifications** | Alertes de fin de timer | Au premier démarrage d’un timer, jamais au lancement de Ledge. |
| **Calendrier** | Affichage du prochain événement | À l’ouverture du module ou depuis la page Permissions. |

> Chaque fonction se **dégrade proprement** sans sa permission (cf. [doc 07](07-architecture-technique.md)).

## Finition du premier lancement (0.1.1)

- Onboarding facultatif en trois écrans, réouvrable depuis la barre de menus : valeur du produit,
  gestes essentiels et explication de la politique de permissions.
- Page Permissions enrichie : états réels Accessibilité, Notifications et Calendrier, distinction
  entre accès non demandé et refusé, actualisation automatique au retour des Réglages Système.
- L’accès Calendrier n’est plus demandé au démarrage de l’app : la demande est maintenant
  contextuelle.
- États vides harmonisés pour Média, Presse-papiers, Drop Zone, Raccourcis et Calendrier, avec une
  action de récupération lorsque c’est pertinent.
- VoiceOver enrichi sur la navigation et le HUD ; les animations principales respectent le réglage
  macOS « Réduire les animations ».
- Sélecteur d'écran fiable dans Réglages → Affichage : écran du Mac par défaut, tous les écrans ou
  sélection multiple persistante. Chaque cible reçoit un panneau léger qui partage les mêmes
  modules ; une fine barre noire remplace l'encoche sur les écrans externes. Une cible déconnectée
  reste mémorisée et revient automatiquement.
- Trois dispositions persistantes dans Réglages → Apparence : Concentrée, Panoramique par défaut
  et Immersive. Elles conservent un fond noir continu avec l'encoche, ajustent largeur, hauteur et
  navigation, et partagent une transition amortie qui respecte « Réduire les animations ».
- L'ouverture est séquencée en deux temps : expansion de la surface noire, puis apparition du
  contenu. Les rayons de la silhouette sont bornés à chaque image pour éviter l'auto-intersection
  des coins en Immersive. Les Réglages emploient un en-tête interne qui ne recouvre plus la première
  section des formulaires.
- Le masque de la silhouette s'applique à toute la hiérarchie du panneau afin que les fonds propres
  aux modules ne puissent plus recouvrir les coins. Média possède une composition intérieure dédiée
  à chaque disposition et la navigation inclut un lanceur de modules en grille redessiné. Dans
  Réglages → Apparence, chaque disposition possède maintenant son propre routage exclusif des
  modules — Barre, Grille ou Masqué —, son propre ordre dans chaque destination et un choix
  indépendant d'affichage du bouton de grille.
  La barre emploie des icônes seules dans toutes les dispositions ; les noms complets restent dans
  VoiceOver et dans la grille. Le panneau reste ouvert tant que le popover de la grille est utilisé.
  La forme ambient est volontairement identique dans les trois dispositions.

## Robustesse des modules (27 septembre 2026)

- Les timers utilisent désormais une échéance absolue : une veille du Mac ou un blocage du run
  loop ne ralentit plus le décompte. La permission Notifications est demandée à l’usage.
- Le presse-papiers maintient réellement les éléments épinglés en tête. Sans permission
  Accessibilité, l’élément est tout de même copié et l’interface explique pourquoi le collage
  automatique n’a pas eu lieu.
- La Drop Zone détecte les fichiers supprimés ou déplacés après leur dépôt, les signale dans la
  grille et les exclut du partage. Les échecs de copie ne sont plus silencieux.
- Calendrier distingue maintenant accès non demandé, accordé et refusé, et ne démarre son polling
  que lorsque l’accès est accordé.
- Raccourcis distingue une liste vide d’un échec de la commande système et affiche aussi l’échec
  éventuel d’un lancement.
- La suite couvre 110 tests dans 17 suites, dont les cas de veille, grille vide, module masqué pendant
  sa sélection, élément épinglé et fichier de Drop Zone devenu indisponible.

## Cycle de vie et confidentialité des modules (Jalon 2, 27 septembre 2026)

- `NotchController` relie désormais réellement `enabled` (réglages globaux ou profil d'app actif)
  au cycle de vie des modules : `register(modules:)` ne démarre que les modules activés, et tout
  changement d'activation (toggle dans Réglages → Modules, ou changement d'app au premier plan
  avec un `AppProfile` correspondant) appelle `stop()`/`start()` en conséquence — voir
  [`NotchController+ModuleLifecycle.swift`](../Sources/Core/NotchWindow/NotchController+ModuleLifecycle.swift)
  et le contrat précis dans [doc 11](11-extensibilite-modules.md).
- Conséquence directe pour la confidentialité : désactiver le presse-papiers (globalement ou via
  un profil d'app, par exemple pour une app bancaire) arrête réellement `ClipboardSource` — plus
  aucune capture tant qu'il reste désactivé. Avant ce correctif, seule la navigation était masquée ;
  le module continuait de tourner en arrière-plan.
- Le module Système reste volontairement hors du catalogue des Réglages → Modules. Seule sa
  batterie transverse est conservée dans la NavBar ; les vues, réglages, jauges, toggles et lanceur
  devenus inaccessibles ont été supprimés au lieu de conserver un second produit caché.
- Les erreurs de persistance du presse-papiers (lecture, écriture, suppression du fichier
  `clipboard-history.json`) ne sont plus silencieuses : `ClipboardHistoryStore` lève désormais des
  erreurs, `ClipboardModule` les expose via `SettingsStore.clipboardPersistenceIssue`, et
  Réglages → Presse-papiers affiche un message explicite avec un bouton « Réessayer » — la capture
  en mémoire continue de fonctionner normalement pendant ce temps.

## Fiabilisation des modules et accessibilité (Jalon 3 et 4, 27 septembre 2026)

**Jalon 3 — fiabiliser les modules**

- L'ancrage du partage dans la Drop Zone utilise désormais `ViewAnchorReader`
  (`Sources/Core/ModuleKit/ViewAnchorReader.swift`), un `NSViewRepresentable` qui capture le vrai
  `NSView` sous la barre d'action — nécessaire car `NotchWindow` est un panel non-activating qui
  ne devient jamais `keyWindow`.
- Une collision de nom de fichier lors d'une copie depuis la Drop Zone ne remplace plus le fichier
  existant : `DropZoneModule.uniqueDestination` ajoute un suffixe façon Finder (« nom 2 », « nom 3 »…).
- L'identification Apple Music/Spotify reposait sur deux booléens conservés entre notifications ;
  avec les deux lecteurs ouverts, une notification Apple Music sans rapport (ex. « Stopped »)
  pouvait écraser l'état affiché de Spotify, et une commande comme le seek pouvait partir vers le
  mauvais lecteur. Remplacé par un état explicite `MediaSourceIdentity` avec un résolveur pur et
  testé (`Tests/MediaModuleTests/MediaSourceIdentityTests.swift`). Le test manuel des deux lecteurs
  ouverts simultanément est documenté dans [doc 12](12-recette-release-candidate.md).
- L'historique du presse-papiers est chiffré sur disque (AES-GCM via CryptoKit, clé générée et
  conservée dans le Trousseau macOS par `ClipboardHistoryKeyStore`) au lieu d'être stocké en JSON en
  clair ; un ancien fichier en clair est lu une dernière fois puis ré-écrit chiffré de façon
  transparente. Nouveau réglage d'exclusion d'apps par bundle identifier et collage en texte brut
  (⌘+clic sur un élément).
- Les timers actifs (minuteurs et Pomodoro) sont désormais persistés entre les lancements de
  l'app (`TimerPersistenceStore`), et un timer déjà expiré au relancement se termine immédiatement
  plutôt que de rester bloqué. Nouveau réglage de peek configurable en fin de minuteur (activable,
  durée 2–10 s), en plus de la notification système.

**Jalon 4 — accessibilité et réglages**

- La barre de progression du module Média expose sa valeur à VoiceOver et répond aux actions
  d'ajustement (±15 s), sans dépendre d'un `Slider` natif.
- Les molettes H:M:S du réglage de minuteur exposent chacune une valeur et des actions
  d'ajustement bornées à leurs valeurs min/max.
- L'aperçu QuickLook d'un fichier dans la Drop Zone, jusque-là déclenché uniquement par un survol
  de souris avec un délai de 450 ms, est maintenant accessible au clavier (barre d'espace) et via
  une action VoiceOver nommée.
- « Système », l'option de langue automatique du sélecteur, était un littéral anglais non localisé ;
  il utilise désormais une clé de localisation comme le reste de l'interface.
- Un échec d'enregistrement du lancement à la connexion (`SMAppService.register()`/`unregister()`)
  était avalé silencieusement par `try?` ; l'erreur est maintenant affichée sous le réglage
  correspondant.
- Nouvelle option **« Réinitialiser tous les réglages »** dans Réglages → À propos, avec
  confirmation : `SettingsStore.resetToDefaults()` (voir
  [`SettingsStore+Reset.swift`](../Sources/Core/Settings/SettingsStore+Reset.swift)) supprime
  toutes les clés `UserDefaults` connues puis relit les valeurs par défaut via une instance
  jetable de `SettingsStore` construite sur les mêmes `UserDefaults` — réutilise la logique de
  `init(defaults:)` plutôt que de dupliquer une cinquantaine de valeurs par défaut dans un second
  endroit qui pourrait diverger.

**P0 de finalisation — cycle de vie et persistance (30 septembre 2026)**

- La migration d'un ancien historique de presse-papiers en clair ne peut plus réussir à moitié :
  l'écriture AES-GCM atomique est obligatoire, son échec remonte comme `.loadFailed`, et le fichier
  original reste intact. Le chemin d'erreur et son état récupérable sont testés avec un writer
  injectable qui simule un disque non inscriptible.
- `TimerModule.stop()` suspend désormais les sources sans vider les entrées ni leur persistance.
  `start()` resynchronise les échéances conservées ; seule l'action explicite
  `clearAllTimers()` supprime définitivement les minuteurs. Le scénario profil d'app est couvert.
- Une Drop Zone désactivée globalement ou par profil ne peut plus ouvrir ni sélectionner le panneau.
  Son arrêt annule le drag courant et retire sa contribution ambient.
- Les observations du presse-papiers et les tâches asynchrones de Média/Raccourcis utilisent un
  état de démarrage et une génération invalidée par `stop()`, empêchant tout callback retardé ou
  double réarmement après un cycle `start()`/`stop()`.

**P2 de maintenance (30 septembre 2026)** : `SettingsStore.swift` (328 lignes) et
`NotchController.swift` (367 lignes) sont désormais sous le seuil de 400 lignes. Les dépendances
aux réglages sont injectées dans Timer, Drop Zone et l'assemblage App. Les erreurs de lecture,
écriture et suppression de `timers.json` sont visibles dans le module et récupérables avec
« Réessayer ». La publication GitHub reprend désormais un brouillon du même commit après un upload
partiel, et `make measure-performance` produit des mesures CPU/RSS CSV reproductibles. Build,
110 tests dans 17 suites et SwiftLint sans avertissement sont verts.

**Polissage d'interface (1er octobre 2026)** : la barre de navigation remplit désormais l'épaule
gauche selon sa capacité réelle avant d'envoyer les modules en débordement à droite de l'encoche.
Le module Raccourcis gagne une recherche, des lignes entièrement cliquables et des retours explicites
de chargement, d'erreur, d'exécution et de succès. Ses favoris sont persistants et remontent en tête
de liste. Ledge peut être affiché sur tous les écrans ou une sélection d'écrans sans dupliquer les
sources des modules. Sur un écran sans encoche, l'état replié devient
une fine barre noire au bord supérieur plutôt qu'une encoche simulée. Enfin, la fenêtre Paramètres
normalise toute taille restaurée à au moins 720 × 520 pt et la replace dans la zone visible.
La page Permissions réévalue aussi ses statuts chaque seconde tant qu'elle est visible, car macOS
ne publie pas de notification TCC fiable lors d'un changement effectué dans Réglages Système ; la
tâche est automatiquement annulée dès que l'utilisateur quitte cette page.
L'aperçu Quick Look de la Drop Zone maintient désormais le panneau ouvert et tolère la traversée
entre la tuile et son popover ; un PDF reste donc interactif sous le pointeur, scrollbar comprise.

## Construire & lancer

```bash
swift build          # compilation
swift run            # build + lancement (agent, pas d'icône Dock)
```

Pour tester le HUD : accepter le prompt **Accessibilité**, puis revenir dans une autre app. Ledge
réinstalle le tap au changement d'application, sans nécessiter de relance.

## Prochaines étapes suggérées

La version publique est `0.2.0`. La candidate locale suivante est `0.3.0` (build `3`) ; elle ne doit
être publiée qu'après la recette de [doc 12](12-recette-release-candidate.md).

1. Fournir au PAT de l'app le scope `workflow`, pousser `codex/release-0.3.0`, puis valider la CI
   GitHub Actions sur le flux `dev → rc → main`. Le vrai push est toujours refusé malgré une
   simulation réussie ; celui du site reste refusé en HTTP 403.
2. Valider Apple Music en lecture réelle : pochette, seek, resynchronisation et permission Automation.
3. Valider manuellement les trois comportements plein écran et les transitions veille/réveil sur
   écran interne et externe.
4. Tester Gatekeeper puis une mise à jour Sparkle `0.2.0` → `0.3.0` sur un autre Mac.
5. Effectuer les recettes manuelles restantes avant d'exécuter `make release` : le DMG et
   l'appcast EdDSA 0.3.0 sont désormais générés et validés par `make verify-release`.
6. Restaurer `ledge.app` vers le déploiement Vercel : le domaine sert actuellement une page de
   parking `/lander` et non les routes de téléchargement et d'appcast.
