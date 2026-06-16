# 09 — Avancement & contexte du projet

> Le *où on en est*. Les docs 01–08 décrivent la **vision** ; celui-ci décrit l'**état réel
> du code** à un instant donné. À mettre à jour au fil des avancées.
>
> Dernière mise à jour : **2026-06-15**

## Vue d'ensemble

Notchy est passé de la phase **conception** (docs 01–08) à une phase **implémentation
active**. Le socle technique (V0) et le premier module riche (Média, V1) sont en place, et les
quatre modules existent au moins en version fonctionnelle. Le travail récent porte sur le
**polissage** (média, alignement de la NavBar) et sur une **nouvelle fonctionnalité système** :
le HUD volume/luminosité maison qui remplace celui de macOS.

| Phase roadmap | État | Détail |
|---|---|---|
| **V0** — Fenêtre + 3 états + animation | ✅ Fait | Fenêtre ancrée, machine à états, hot zone, détection dynamique de l'encoche. |
| **V1** — Module Média | ✅ Fonctionnel | Lecture, contrôles, pochette (partiel), barre de progression scrubbable. |
| **V2** — Timers + Drop Zone | ✅ Présent | Modules implémentés. |
| **V3** — Presse-papiers + Système | ✅ Présent | Modules implémentés + HUD volume/luminosité (nouveau). |
| **V4** — Paramètres complets | 🔄 En cours | Fenêtre réglages multi-sections en place, i18n, toggles. |

## Pile technique réelle

Conforme à la [doc 07](07-architecture-technique.md), avec quelques précisions issues du code :

- **Swift Package Manager** (pas de projet Xcode). `swift-tools-version: 5.10`, cible
  **macOS 14+**, localisation par défaut `en`.
- Découpage en cibles : `App` (exécutable) → `Core` + 5 modules (`MediaModule`,
  `TimerModule`, `DropZoneModule`, `ClipboardModule`, `SystemModule`).
- **AppKit** (`NSPanel` borderless non-activating) pour la fenêtre encoche + **SwiftUI**
  (`NSHostingView`) pour le contenu.
- `SystemModule` lie **IOKit** et **CoreAudio** (`linkerSettings` dans [Package.swift](../Package.swift)).
- Frameworks privés via `dlopen`/`dlsym` : **MediaRemote** (média), **DisplayServices**
  (luminosité sur Apple Silicon).
- Build & run : `swift build` / `swift run`. Signature ad-hoc (pas encore de bundle `.app`
  signé/notarisé).

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

**Objectif** : afficher la barre maison de Notchy quand on change le volume ou la luminosité,
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
- Réglage **activé** (défaut) : la barre Notchy s'affiche (via polling, sans permission) ; le HUD
  macOS est supprimé **dès que l'Accessibilité est accordée** (le `CGEventTap` peut alors agir).
- Réglage **désactivé** : comportement macOS natif, Notchy ne montre rien.

## Limites connues / points ouverts

| Sujet | État | Détail |
|---|---|---|
| **Pochette d'album** | ⚠️ Partiel | MediaRemote est bloqué pour Apple Music sur macOS 15 (run non-bundlé) ; la notification distribuée `com.apple.Music.playerInfo` ne fournit pas d'image. Piste : `iTunesLibrary` via « Persistent ID ». |
| **Seek Apple Music** | ✅ Contourné | MediaRemote bloqué → on passe par **AppleScript** (`set player position`) pour Music, MediaRemote (`MRMediaRemoteSetElapsedTime`) pour les autres lecteurs. Demande la permission **Automation** au 1er usage. |
| **Suppression HUD natif en `swift run`** | ⚠️ Fragile | Le `CGEventTap` exige l'Accessibilité accordée au binaire `.build/.../notchy`. Plus fiable avec un vrai `.app` signé. La barre Notchy elle-même (polling) marche sans permission. |
| **Distribution** | ⏳ À faire | Pas encore de bundle `.app` signé/notarisé ni de mécanisme de mise à jour (Sparkle). |

## Permissions requises (récapitulatif)

| Permission | Pour quoi | Quand |
|---|---|---|
| **Accessibilité** | `CGEventTap` (supprimer le HUD natif volume/luminosité) | Prompt au lancement si le réglage HUD est actif. |
| **Automation (Music)** | Seek dans Apple Music via AppleScript | Prompt au 1er glissement sur la barre. |
| **Notifications** | Alertes de fin de timer | À la 1re alerte. |

> Chaque fonction se **dégrade proprement** sans sa permission (cf. [doc 07](07-architecture-technique.md)).

## Construire & lancer

```bash
swift build          # compilation
swift run            # build + lancement (agent, pas d'icône Dock)
```

Pour tester le HUD : accepter le prompt **Accessibilité**, puis **relancer l'app**.

## Prochaines étapes suggérées

1. **Pochette d'album** fiable (piste `iTunesLibrary` / cache image).
2. **Bundle `.app`** signé + notarisé → fiabilise Accessibilité/Automation et la distribution.
3. Finaliser **V4** : personnalisation des modules, page Permissions complète.
4. Vérifier les cas **multi-écran / plein écran** décrits en [doc 07](07-architecture-technique.md).
