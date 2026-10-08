# 09 — Avancement & contexte du projet

> Le *où on en est*. Les docs 01–08 décrivent la **vision** ; celui-ci décrit l'**état réel
> du code** à un instant donné. À mettre à jour au fil des avancées.
>
> Dernière mise à jour : **2026-10-07**

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
  **macOS 14+**, localisation par défaut `en`. Les suites `import Testing` exigent une toolchain
  **Swift 6 / Xcode 16+**, même si le manifeste conserve son mode de compatibilité Swift 5.10.
- Découpage en cibles : `App` (exécutable) → `Core` + 8 modules (`MediaModule`, `TimerModule`,
  `DropZoneModule`, `ClipboardModule`, `SystemModule`, `ShortcutsModule`, `CalendarModule`,
  `NotesModule`).
- **AppKit** (`NSPanel` borderless non-activating) pour la fenêtre encoche + **SwiftUI**
  (`NSHostingView`) pour le contenu.
- `SystemModule` lie **IOKit** et **CoreAudio** (`linkerSettings` dans [Package.swift](../Package.swift)).
- Frameworks privés via `dlopen`/`dlsym` : **MediaRemote** (média), **DisplayServices**
  (luminosité sur Apple Silicon).
- Build rapide : `swift build` / `swift test`. Les permissions se testent avec `make app`; la
  distribution publique gratuite passe par un DMG ad hoc et un appcast signé avec Sparkle EdDSA.
  Le parcours Developer ID/notarisé reste disponible en option.

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
| **Suppression HUD natif** | ✅ OK (bundle signé) | Le `CGEventTap` consomme les touches volume/luminosité **si l'Accessibilité est accordée**. Tester via `dist/Ledge.app` (`make app`), pas `swift run` (pas de bundle = pas de permission). `make app` préfère une identité Apple Development stable, mais la machine actuelle n'en possède aucune et retombe sur l'ad hoc : l'autorisation peut alors être redemandée après un rebuild. La barre Ledge (volume événementiel) marche sans permission. |
| **Distribution** | ✅ Code prêt | Le bundle possède une icône native et le DMG propose `Ledge.app → Applications`. `make release` publie le paquet ad hoc gratuit ; la notice et le site expliquent la tentative d'ouverture nécessaire avant « Ouvrir quand même ». |

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
Les boutons « Ajouter une app… » du presse-papiers et « Ajouter un profil » utilisent explicitement
le bundle Core de localisation, évitant l'affichage brut de leur clé dans la cible App.
Après une veille ou un déverrouillage de session, le module Système recrée désormais son
`CGEventTap` avec trois tentatives bornées. Cela évite que le HUD Ledge et le HUD natif macOS
s'affichent ensemble lorsque l'ancien Mach port existe encore mais n'intercepte plus les touches.

**Phase 2 — fiabilité v1 (5 octobre 2026)** : la Drop Zone copie désormais hors du thread
principal, publie une progression et permet l'annulation. Le presse-papiers conserve les images
en pleine définition, ignore ses propres écritures et documente honnêtement la limite macOS de
l'identification de l'app source. Les commandes Raccourcis ont des délais maximaux (5 s pour la
liste, 30 s pour une exécution), une annulation qui termine le processus et des erreurs visibles.
Les erreurs système de permissions Calendrier/Notifications ne sont plus confondues avec un refus.
Les animations Ambient respectent « Réduire les animations » et les conflits Carbon des
raccourcis globaux apparaissent dans les réglages. `swift build`, **116 tests dans 17 suites** et
SwiftLint sont verts, sans avertissement.

**Phase 3 — release candidate locale (5 octobre 2026)** : le bundle optimisé, le DMG et l'appcast
0.3.0 ont été régénérés et validés. Le DMG pèse 3 565 185 octets et son SHA-256 est
`8b6078d6744a1c9b0c96648a8824ca4807ebb589f59a7eb69059603ef241e1d9`. Au repos stabilisé,
Ledge mesure 0,00 % CPU moyen et 91,1 Mo RSS moyen sur 30 secondes. La vérification actuelle ne
trouve aucune identité de signature valide : Gatekeeper rejette normalement le paquet ad hoc et
aucune notarisation n'est possible sans certificat Developer ID et configuration NotaryTool. Le site
local est vert (lint, 33 tests, contrat visuel, build), tandis que la recette interactive, le
second Mac, la validation juridique anglaise et deux réglages Vercel restent bloquants.

**Synchronisation du site et des captures (5 octobre 2026)** : `MarketingCapture` ne code plus la
version 0.2.0 dans son manifeste. Le script du site lit la version 0.3.0 dans `Info.plist`, la passe
explicitement au générateur et le contrat visuel contrôle la version ainsi que la présence des dix
PNG. Les captures 0.3.0 ont été régénérées dans `ledge-site`. Le site dispose aussi d'un fallback
de release, d'en-têtes de sécurité, d'une page Support FR/EN, d'un inventaire de licences généré et
d'une home raccourcie. Sa recette finale passe ESLint, **31 tests**, le contrat visuel 0.3.0 et le
build Next.js sans avertissement. Aucun push n'a été effectué.

**Correction du paquet de distribution (7 octobre 2026)** : le bundle principal déclare désormais
une vraie icône macOS compilée dans `Assets.car`. Le DMG contient `Ledge.app`, un raccourci
`Applications` et une notice FR/EN, avec des vérifications automatiques du bundle et du volume.
L'échec observé sur un autre Mac venait aussi d'un parcours incomplet : ouvrir le DMG ne déclenche
pas Gatekeeper. L'utilisateur doit copier Ledge dans Applications, tenter de l'ouvrir, fermer
l'alerte, puis utiliser « Ouvrir quand même » dans l'heure. Le DMG et le site détaillent désormais
ces étapes. `make release` publie ce paquet ad hoc gratuit ; `make release-notarized` conserve le
parcours Apple optionnel, avec signature Sparkle de l'intérieur vers l'extérieur, signature du DMG
et vérification du ticket. La recette locale de ce nouveau format passe `make verify-release`.

**Correction CI et versioning (8 octobre 2026)** : les deux premières CI `Quality` exécutées sur
`main` avec Swift 5.10 ont révélé par étapes des accès UI insuffisamment isolés, alors que la
toolchain Swift 6.2 locale les acceptait implicitement. Le premier correctif couvrait
`AmbientView`, `ExpandedView` et `ModuleLauncherButton`; le run suivant a atteint puis signalé
`NavBar` et `NotchContentView`. Le passage a donc été étendu à toutes les vues qui conservent ou
lisent un `NotchController`, un `NotchModule` ou une implémentation de module `@MainActor`, y
compris les vues compactes et détaillées des huit modules. La chaîne locale équivalente à
`Quality` est verte : tests de l'automatisation de release, `swift build`, **116 tests dans 17
suites**, SwiftLint sans avertissement, création ad hoc de `Ledge.app` et vérification de son
bundle. Le run Swift 5.10 suivant a ensuite atteint `CalendarModule` et révélé une capture faible
non répétée dans la tâche `@MainActor` du minuteur de rafraîchissement ; cette capture est désormais
explicite dans les deux fermetures. Le build a alors passé cette étape, puis les tests ont échoué
avant exécution avec `no such module 'Testing'` : le runner `macos-14` sélectionnait Xcode 15.4,
qui ne fournit pas Swift Testing. Les workflows `Quality` et `Release version` utilisent désormais
`macos-15` avec Xcode 16.4 explicitement sélectionné ; la clé de cache Swift inclut cette version
pour ne pas restaurer d'artefacts produits par une autre toolchain. Les actions officielles
`checkout` et `cache` sont en v5 afin d'utiliser Node 24 et de ne pas dépendre du runtime Node 20
retiré par GitHub. Le versioning n'utilise plus de patch implicite : sans label,
aucune PR de release n'est créée. Seuls `version:patch`, `version:minor` et `version:major`
déclenchent un bump, et `version:none` reste un arrêt explicite. Un job indépendant crée ou remet à
jour ces quatre labels même lorsque `Quality` échoue. Chaque propagation `branche → dev → rc →
main` doit rester conditionnée à une CI `Quality` verte sur la PR correspondante.

Le premier run sous Xcode 16.4 a aussi exposé une attente fixe fragile dans
`showPeekAutoCollapsesAfterDuration` : le test dormait 100 ms avant de lire l'état, ce qui pouvait
échouer lorsque le `MainActor` était chargé par l'exécution parallèle. Il attend désormais la
condition `collapsed` avec le helper borné `eventually`, déjà utilisé par les autres tests
asynchrones de `NotchController`.

La préparation de `v1.0.0` a ensuite révélé que GitHub peut refuser `gh pr create` lorsque le
réglage du dépôt autorisant Actions à créer des pull requests est désactivé. Le script zsh ne
propageait pas ce code d'erreur et affichait donc le job en succès, en laissant la branche de
release sans PR. L'étape vérifie désormais explicitement le résultat : elle échoue et supprime la
branche temporaire si la création de la PR est refusée.

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

1. Aucun push ne doit être effectué par l'agent. Si Adrien décide de publier les branches, il devra
   lui-même valider ensuite les CI distantes de l'application et du site.
2. Valider Apple Music en lecture réelle : pochette, seek, resynchronisation et permission Automation.
3. Valider manuellement les trois comportements plein écran et les transitions veille/réveil sur
   écran interne et externe.
4. Tester sur un Mac Apple Silicon propre le parcours complet : copie vers Applications, première
   tentative, apparition de « Ouvrir quand même » puis lancement.
5. Tester une mise à jour Sparkle `0.2.0` → `0.3.0` avant d'exécuter `make release`.
6. Finaliser le domaine Vercel : `app-ledge.fr` est connecté et HTTPS fonctionne, mais Vercel
   redirige encore l'apex vers `www.app-ledge.fr` alors que le code déclare l'apex canonique.
   `ledge.app` appartient à un tiers et ne fait pas partie du projet.
