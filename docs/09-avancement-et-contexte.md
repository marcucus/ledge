# 09 — Avancement & contexte du projet

> Le *où on en est*. Les docs 01–08 décrivent la **vision** ; celui-ci décrit l'**état réel
> du code** à un instant donné. À mettre à jour au fil des avancées.
>
> Dernière mise à jour : **2026-09-25**

## Vue d'ensemble

Ledge est passé de la phase **conception** (docs 01–08) à une phase **implémentation
active**. Le socle technique (V0) et le premier module riche (Média, V1) sont en place, et les
les huit modules existent au moins en version fonctionnelle. Le travail récent porte sur le
**polissage** (média, alignement de la NavBar) et sur une **nouvelle fonctionnalité système** :
le HUD volume/luminosité maison qui remplace celui de macOS.

| Phase roadmap | État | Détail |
|---|---|---|
| **V0** — Fenêtre + 3 états + animation | ✅ Fait | Fenêtre ancrée, machine à états, hot zone, détection dynamique de l'encoche. |
| **V1** — Module Média | ✅ Fonctionnel | Lecture, contrôles, pochette (partiel), barre de progression scrubbable. |
| **V2** — Timers + Drop Zone | ✅ Présent | Modules implémentés. |
| **V3** — Presse-papiers + Système | ✅ Présent | Modules implémentés + HUD volume/luminosité (nouveau). |
| **V4** — Paramètres complets | ✅ Fait | Réglages multi-sections, onboarding, permissions centralisées, i18n et accessibilité. |

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
| États | [NotchState.swift](../Sources/Core/NotchWindow/NotchState.swift) | `collapsed` · `peeking` · `hud` · `expanded`. |
| Contenu racine | [NotchContentView.swift](../Sources/Core/NotchWindow/NotchContentView.swift) | Aiguille NavBar / HUDBar / module selon l'état. |
| Forme | [NotchPanelShape.swift](../Sources/Core/NotchWindow/NotchPanelShape.swift) | Tracé arrondi du panneau (oreilles + rayon bas). |
| Géométrie | [NotchGeometry/](../Sources/Core/NotchGeometry/) | Détection dynamique de l'encoche (`safeAreaInsets`, zones auxiliaires). |
| Protocole module | [NotchModule.swift](../Sources/Core/ModuleKit/NotchModule.swift) | Contrat pluggable : icône d'onglet, vue aperçu, vue complète. |
| HUD | [HUDContent.swift](../Sources/Core/HUDContent.swift) | Struct publique (kind volume/luminosité, valeur 0–1, mute, teinte). |
| Réglages | [Core/Settings/](../Sources/Core/Settings/) | `SettingsStore` + enums. |
| i18n | [Localization.swift](../Sources/Core/Localization.swift) | Bundle de localisation + override de langue à chaud. |

### Les états de l'encoche

- **collapsed** — au repos, fenêtre à la taille exacte de l'encoche physique.
- **ambient** — extension latérale discrète pour musique, timer ou Drop Zone.
- **peeking** — aperçu compact (largeur expanded, hauteur NavBar).
- **hud** — barre compacte volume/luminosité : fenêtre qui **entoure l'encoche**
  (`notchWidth + 170` de large, `notchHeight + 34` de haut), barre fine centrée **sous**
  l'encoche. Auto-dismiss après 1,6 s.
- **expanded** — panneau complet (744 px de large, NavBar 44 px + contenu 180 px).

## État par module

| Module | Fichiers clés | État | Notes |
|---|---|---|---|
| 🎵 **Média** | [MediaModule](../Sources/Modules/Media/MediaModule.swift), [MediaRemoteSource](../Sources/Modules/Media/MediaRemoteSource.swift), [MediaContentView](../Sources/Modules/Media/MediaContentView.swift) | ✅ Fonctionnel | Titre/artiste/album, play-pause/préc./suiv., timer écoulé, **barre scrubbable**. Pochette partielle (voir limites). |
| ⏱️ **Timers** | [TimerModule](../Sources/Modules/Timer/TimerModule.swift), [TimerContentView](../Sources/Modules/Timer/TimerContentView.swift) | ✅ Présent | Minuteurs/Pomodoro, anneau, notifications. |
| 📁 **Drop Zone** | [DropZoneModule](../Sources/Modules/DropZone/DropZoneModule.swift) | ✅ Présent | Étagère de fichiers ; ouverture auto au drag de fichiers près de l'encoche. |
| 📋 **Presse-papiers** | [ClipboardModule](../Sources/Modules/Clipboard/ClipboardModule.swift) | ✅ Présent | Historique de copies (seul polling toléré). |
| ⚙️ **Système** | [SystemModule](../Sources/Modules/System/SystemModule.swift), [SystemObserver](../Sources/Modules/System/SystemObserver.swift) | ✅ Présent | Jauges (batterie/CPU/RAM), toggles rapides, **+ HUD volume/luminosité**. |

## Focus : le HUD volume / luminosité (travail récent)

Nouvelle brique dans `SystemModule`, indépendante des jauges.

**Objectif** : afficher la barre maison de Ledge quand on change le volume ou la luminosité,
et **remplacer** l'overlay natif de macOS.

**Composants**
- [SystemObserver.swift](../Sources/Modules/System/SystemObserver.swift) — détection et contrôle bas niveau :
  - **Volume** via CoreAudio (`kAudioDevicePropertyVolumeScalar` / `…Mute`), lecture + écriture.
  - **Luminosité** via **DisplayServices** (`DisplayServicesGet/SetBrightness`) sur Apple Silicon,
    fallback IOKit (`IODisplayGetFloatParameter`) sur Intel.
  - **Polling 0,2 s** : capte les changements (touches clavier non interceptées + Centre de
    contrôle) sans aucune permission.
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
- Réglage **activé** (défaut) : la barre Ledge s'affiche (via polling, sans permission) ; le HUD
  macOS est supprimé **dès que l'Accessibilité est accordée** (le `CGEventTap` peut alors agir).
- Réglage **désactivé** : comportement macOS natif, Ledge ne montre rien.

## Limites connues / points ouverts

| Sujet | État | Détail |
|---|---|---|
| **Pochette d'album** | ⚠️ Partiel | MediaRemote est bloqué pour Apple Music sur macOS 15 (run non-bundlé) ; la notification distribuée `com.apple.Music.playerInfo` ne fournit pas d'image. Piste : `iTunesLibrary` via « Persistent ID ». |
| **Seek Apple Music** | ✅ Contourné | MediaRemote bloqué → on passe par **AppleScript** (`set player position`) pour Music, MediaRemote (`MRMediaRemoteSetElapsedTime`) pour les autres lecteurs. Demande la permission **Automation** au 1er usage. |
| **Suppression HUD natif** | ✅ OK (bundle signé) | Le `CGEventTap` consomme les touches volume/luminosité **si l'Accessibilité est accordée**. Tester via `dist/Ledge.app` (`make app`), pas `swift run` (pas de bundle = pas de permission). `make app` signe avec une identité Apple Development **stable** → l'autorisation persiste entre les rebuilds. La barre Ledge (volume événementiel) marche sans permission. |
| **Distribution** | ✅ Code prêt | `make release` crée un bundle ad hoc et un DMG sans compte Apple, signe la mise à jour avec Sparkle EdDSA puis publie le DMG et l'appcast dans GitHub Releases. Gatekeeper impose une autorisation manuelle au premier lancement. |

## Permissions requises (récapitulatif)

| Permission | Pour quoi | Quand |
|---|---|---|
| **Accessibilité** | `CGEventTap` (supprimer le HUD natif volume/luminosité) | Prompt au lancement si le réglage HUD est actif. |
| **Automation (Music)** | Seek dans Apple Music via AppleScript | Prompt au 1er glissement sur la barre. |
| **Notifications** | Alertes de fin de timer | À la 1re alerte. |
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
- Sélecteur d'écran fiable dans Réglages → Affichage : écran du Mac par défaut ou écran externe
  explicite, pseudo-encoche sur les écrans sans encoche, cible persistante et restauration après
  une déconnexion temporaire.

## Construire & lancer

```bash
swift build          # compilation
swift run            # build + lancement (agent, pas d'icône Dock)
```

Pour tester le HUD : accepter le prompt **Accessibilité**, puis **relancer l'app**.

## Prochaines étapes suggérées

1. Valider Apple Music en lecture réelle : pochette, seek, resynchronisation et permission Automation.
2. Vérifier et corriger les trois comportements plein écran, puis les transitions veille/réveil.
3. Tester le parcours Gatekeeper « Ouvrir quand même » sur une autre machine.
4. Continuer la passe de robustesse sur les erreurs et opérations impossibles des modules.
