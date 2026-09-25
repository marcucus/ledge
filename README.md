# Ledge — app d'encoche pour macOS

> Une app qui transforme l'encoche du MacBook en menu interactif léger, façon Dynamic Island,
> avec des modules pluggables.

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

## Les modules

| Module | Résumé |
|---|---|
| 🎵 Média | Pochette qui déborde de l'encoche, contrôles, scrubbing, mode ambient. Apple Music (ScriptingBridge), autres lecteurs (`MediaRemote`), pochette Spotify. |
| 📋 Presse-papiers | Historique de copies, **épinglage** (favoris hors purge) + **recherche**, persistance disque optionnelle (RAM par défaut). |
| 📥 Drop Zone | Étagère de fichiers, glisser-déposer **entrant et sortant**, **aperçu QuickLook** au survol, partage AirDrop. |
| ⚙️ Système | Jauges (batterie/CPU/RAM/réseau, **micro en cours**, **batterie des accessoires Bluetooth**), toggles rapides, lanceur d'apps. |
| ⏱️ Timers | **Molette H:M:S** + presets, Pomodoro, décompte en direct dans l'ambient. |
| ⚡ Raccourcis | Lister et lancer les raccourcis de Shortcuts.app. |
| 📅 Calendrier | Prochain événement à venir (EventKit). |
| 📝 Notes | Note texte libre éphémère sous l'encoche. |

**Transverses :** HUD volume/luminosité (remplace l'OSD système), **thèmes** nommés (couleur + opacité + rayon), **profils de modules par app active**. Extensibilité interne via le contrat `NotchModule` ([doc 11](docs/11-extensibilite-modules.md)).

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
| [10 — Audit & plan](docs/10-audit-et-plan.md) | Audit qualité/sécurité/perf + plan jalonné et suivi des développements. |
| [11 — Extensibilité des modules](docs/11-extensibilite-modules.md) | Le contrat `NotchModule` : anatomie d'un module, 3 points d'assemblage, et pourquoi pas de plugins tiers dynamiques. |


## Roadmap

| Phase | Contenu | État |
|---|---|---|
| **V0** | Fenêtre ancrée sous l'encoche + états (repos/survol/ouvert/ambient/HUD) + animations. | ✅ |
| **V1** | Module Média. | ✅ |
| **V2** | Timers + Drop Zone. | ✅ |
| **V3** | Presse-papiers + Système. | ✅ |
| **V4** | Écran Paramètres complet + personnalisation des modules. | ✅ |
| **V5** | Modules additionnels (Raccourcis, Calendrier, Notes), thèmes, profils par app, HUD système, distribution directe + Sparkle. | ✅ |

> Suivi détaillé et prochaines pistes : [doc 10 — Audit & plan](docs/10-audit-et-plan.md).

## Publication gratuite

Les binaires sont hébergés par GitHub Releases, sans bucket ni service payant. Le token GitHub fin
est limité à ce dépôt avec la permission `Contents: write` et conservé dans le Trousseau macOS sous
le service `dev.ledge.github-release-token`. Depuis un commit propre déjà poussé sur `origin/main` :

```bash
make release CHANGELOG="Première bêta publique"
```

Le script crée une release brouillon, téléverse le DMG et l'appcast signé, puis la publie. Le flux
Sparkle stable est
`https://github.com/marcucus/ledge/releases/latest/download/appcast.xml`.

## Statut

🛠️ **Implémentation avancée** — la fenêtre encoche (5 états), les modules (Média, Timers, Drop
Zone, Presse-papiers, Système, Raccourcis, Calendrier, Notes), l'écran Paramètres et la
distribution directe (DMG ad hoc sur GitHub Releases + Sparkle) sont en place. Détail de l'avancée et du contexte
technique : [doc 09](docs/09-avancement-et-contexte.md) · plan & suivi : [doc 10](docs/10-audit-et-plan.md).

## Licence

**Proprietary — © 2026 Adrien Marques. Tous droits réservés.**

Le code est visible publiquement à titre de transparence et de portfolio, mais il n'est **pas
open source** : copie, modification, compilation, distribution et revente sont interdites sans
accord écrit. Voir [LICENSE](LICENSE).
