# Ledge — app d'encoche pour macOS

> Nom de travail. Une app qui transforme l'encoche du MacBook en menu interactif léger,
> façon Dynamic Island, avec des modules pluggables.

## Objectif

Une app **ultra-légère** (Swift natif, aucun runtime tiers) qui dort tant que l'utilisateur
n'interagit pas, et qui étend l'encoche en un panneau riche au survol / au clic.

**Principe de légèreté :** la conso ne vient pas du langage seul, mais du fait de
**ne presque rien faire au repos** — on privilégie l'événementiel (listeners CoreAudio pour le
volume, observateurs système), le polling restant est borné/à intervalle large, et les jauges ne
se rafraîchissent que panneau ouvert.

## Stack retenue

- **AppKit** → la fenêtre flottante ancrée sous l'encoche (gestion fine position / multi-écran / plein écran).
- **SwiftUI** → le contenu des panneaux et widgets.
- **`LSUIElement`** → agent en arrière-plan, pas d'icône dans le Dock.
- **Multilingue** → suit la langue du Mac par défaut, sélecteur de langue dans les Paramètres (String Catalog, aucun texte en dur).
- Cible : Apple Silicon, macOS 14+ (encoche = MacBook Pro/Air 2021+).

## Les 4 modules

| Module | Résumé |
|---|---|
| 🎵 Média | Pochette qui déborde de l'encoche, contrôles, scrubbing. Via `MediaRemote`. |
| 📋 Presse-papiers + Drop Zone | Historique de copies + étagère de fichiers + partage rapide. |
| ⚙️ Système | Jauges (batterie/CPU/RAM), toggles rapides, lanceur d'apps. |
| ⏱️ Timers & notifs | Minuteurs/Pomodoro (anneau autour de l'encoche), rappels, agrégation de notifs. |

## Documentation

| Doc | Contenu |
|---|---|
| [01 — Concept & interaction](docs/01-concept-et-interaction.md) | Vision, les 3 états de l'encoche, wireframes globaux. |
| [02 — Module Média](docs/02-module-media.md) | Approfondissement + wireframes + données + paramètres. |
| [03 — Presse-papiers & Drop Zone](docs/03-module-presse-papiers-dropzone.md) | Idem. |
| [04 — Système](docs/04-module-systeme.md) | Idem. |
| [05 — Timers & notifications](docs/05-module-timers-notifications.md) | Idem. |
| [06 — Écran Paramètres](docs/06-ecran-parametres.md) | Réglages globaux + par module + les 4 choix critiques. |
| [07 — Architecture technique](docs/07-architecture-technique.md) | Légèreté, détection dynamique de l'encoche, multi-écran, plein écran, permissions. |
| [08 — Conventions de code](docs/08-conventions-de-code.md) | Standards Swift/SwiftUI : structure, style, qualité, outillage. La constitution du code. |
| [09 — Avancement & contexte](docs/09-avancement-et-contexte.md) | État réel du code : ce qui est implémenté par module, le HUD volume/luminosité, limites connues, prochaines étapes. |


## Roadmap

| Phase | Contenu |
|---|---|
| **V0** | Fenêtre ancrée sous l'encoche + 3 états (repos/survol/ouvert) + animation. 80 % de la difficulté technique. |
| **V1** | Module Média. |
| **V2** | Timers + Drop Zone. |
| **V3** | Presse-papiers + Système. |
| **V4** | Écran Paramètres complet + personnalisation des modules. |

## Statut

🛠️ **Implémentation avancée** — la fenêtre encoche (5 états), les modules (Média, Timers, Drop
Zone, Presse-papiers, Système, Raccourcis, Calendrier, Notes), l'écran Paramètres et la
distribution (DMG signé/notarisé + Sparkle) sont en place. Détail de l'avancée et du contexte
technique : [doc 09](docs/09-avancement-et-contexte.md) · plan & suivi : [doc 10](docs/10-audit-et-plan.md).

## Licence

**Proprietary — © 2026 Adrien Marques. Tous droits réservés.**

Le code est visible publiquement à titre de transparence et de portfolio, mais il n'est **pas
open source** : copie, modification, compilation, distribution et revente sont interdites sans
accord écrit. Voir [LICENSE](LICENSE).
