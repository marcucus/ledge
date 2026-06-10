# 04 — Module Système ⚙️

> Jauges + toggles rapides + lanceur. Implémentation V3.

## Objectif

Voir l'état de la machine d'un coup d'œil et accéder aux réglages/raccourcis qu'on touche
le plus souvent, sans ouvrir Réglages Système ni fouiller la barre de menu.

## Wireframes

### État Survol (jauges compactes)

```
        ╭───────────────────────────────────────╮
   ●●●  │  🔋 84%   ⚡ CPU 12%   ▦ RAM 9,1 Go    │  menu bar
        ╰───────────────────────────────────────╯
```

### État Ouvert

```
╭──────────────────────────────────────────────────────╮
│  🎵  📋  ⚙️  ⏱️                              ⚙   ✕    │
├──────────────────────────────────────────────────────┤
│  JAUGES                                                │
│  🔋 Batterie  84% ─ en charge ─ 312 cycles ─ 4h12 rest.│
│  ⚡ CPU       ▁▂▃▂▁▂▅▂  12%                             │
│  ▦ Mémoire    ███████░░░  9,1 / 16 Go                  │
│  🌐 Réseau    ↓ 1,2 Mo/s  ↑ 0,1 Mo/s                   │
├──────────────────────────────────────────────────────┤
│  TOGGLES RAPIDES                                       │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐                    │
│  │ 🌙 │ │ ☕ │ │ 🔆 │ │ 🔕 │ │ 📶 │                    │
│  │NPD │ │Café│ │Lum.│ │Son │ │Wifi│                    │
│  └────┘ └────┘ └────┘ └────┘ └────┘                    │
│  (NPD = Ne Pas Déranger · Café = anti-veille)          │
├──────────────────────────────────────────────────────┤
│  LANCEUR                                               │
│  [Safari] [VS Code] [Terminal] [Figma]  [ + ]          │
╰──────────────────────────────────────────────────────╯
```

## Fonctionnalités

### Jauges
| Jauge | Source | Note |
|---|---|---|
| Batterie | `IOKit` (`IOPowerSources`) | %, charge, cycles, santé, temps restant. |
| CPU | `host_processor_info` | charge globale + mini-graphe. |
| RAM | `vm_statistics64` | utilisée / totale. |
| Réseau | compteurs d'interface | débits ↓/↑ instantanés. |
| Disque / Température | optionnel | température via SMC (sensible selon modèle). |

### Toggles rapides
| Toggle | Mécanisme |
|---|---|
| Ne Pas Déranger / Focus | Le plus délicat — pas d'API publique propre. Voir notes. |
| Café (anti-veille) | `caffeinate` / `IOPMAssertion` (API publique, simple). |
| Luminosité écran | `CoreDisplay` / private brightness API. |
| Volume / Muet | `CoreAudio` (public). |
| Wi-Fi | `CoreWLAN` (public). |
| Dark/Light mode | scripting (`AppleScript`/`osascript`) — pas d'API publique directe. |

> ⚠️ Plusieurs toggles « système » n'ont pas d'API publique stable (Focus, luminosité, dark mode).
> Concevoir chaque toggle comme **optionnel et dégradable** : si l'API n'est pas dispo / casse,
> le toggle se masque proprement plutôt que de planter. L'anti-veille et le volume sont les plus sûrs → commencer par eux.

### Lanceur
- Apps / dossiers / raccourcis (Shortcuts.app) épinglés.
- Glisser une app depuis le Finder pour l'ajouter.
- Optionnel : raccourcis clavier globaux pour lancer.

## Comportement événementiel (légèreté) — POINT CLÉ

C'est le module le plus à risque pour la conso. Règles :
- **Aucune jauge ne tourne au repos.**
- Les jauges (CPU/RAM/réseau) ne s'échantillonnent **que** quand le panneau est ouvert,
  à fréquence modérée (~1 s), et **s'arrêtent** dès qu'il se ferme.
- La batterie utilise les **notifications** `IOPowerSources` (événementiel, pas de polling).
- Les toggles ne lisent leur état qu'à l'ouverture.

## Paramètres du module

- [ ] Activer le module Système
- [ ] Quelles jauges afficher (batterie / CPU / RAM / réseau / température)
- [ ] Fréquence de rafraîchissement panneau ouvert (0,5 / 1 / 2 s)
- [ ] Quels toggles afficher + leur ordre
- [ ] Apps/raccourcis du lanceur (liste éditable)
- [ ] Alertes (ex. batterie < 20 %, RAM saturée) → peek auto

## Cas limites

- **Mac sans batterie** (jamais le cas sur MacBook à encoche, mais via écran externe sur Mac mini ? non — pas d'encoche) → masquer la jauge batterie.
- **API toggle indisponible** → masquer le toggle, log discret.
- **Permissions** (Accessibilité / Automation pour certains toggles) → cf. [Architecture](07-architecture-technique.md) et [Paramètres](06-ecran-parametres.md).
