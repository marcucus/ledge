# 05 — Module Timers & Notifications ⏱️

> Minuteurs/Pomodoro + rappels + agrégation de notifs. Implémentation V2 (timers) → V4 (notifs).

## Objectif

Lancer un minuteur en 2 clics et le suivre **sans ouvrir l'app** grâce à un anneau de
progression autour de l'encoche. Optionnellement, capter les notifications système dans
l'encoche plutôt que dans le coin de l'écran.

## Wireframes

### État Repos — anneau autour de l'encoche (signature)

```
            ╭━━━━━━━━━━━━━━━╮
           ╱   ENCOCHE       ╲      ← un anneau de progression
   ●●●    │   ◜‾‾‾‾‾‾‾‾‾◝     │       borde l'encoche pendant
           ╲   12:34 rest.   ╱        un décompte (très discret)
            ╰━━━━━━━━━━━━━━━╯
```

### État Ouvert — onglet Timers

```
╭──────────────────────────────────────────────────────╮
│  🎵  📋  ⚙️  ⏱️                              ⚙   ✕    │
├──────────────────────────────────────────────────────┤
│  MINUTEUR RAPIDE                                       │
│   [ 5 ]  [ 10 ]  [ 25 ]  [ 60 ] min     [ ⌨ perso ]    │
│                                                        │
│         ◜‾‾‾‾‾‾‾‾‾‾◝                                   │
│        │    12:34    │   ▸ Pause   ◼ Stop              │
│         ◟__________◞     Pomodoro 2/4                  │
├──────────────────────────────────────────────────────┤
│  POMODORO                                              │
│   Travail 25 · Pause 5 · Longue pause 15 (toutes 4)    │
│   [ Démarrer une session ]                             │
├──────────────────────────────────────────────────────┤
│  RAPPELS RAPIDES                                       │
│   "Réunion" ⏰ dans 10 min          [ ✎ ] [ ✕ ]        │
│   "Sortir le linge" ⏰ à 18:00       [ ✎ ] [ ✕ ]        │
│   [ + Nouveau rappel ]                                 │
╰──────────────────────────────────────────────────────╯
```

### État Survol — onglet Notifications (si activé)

```
        ╭───────────────────────────────────────╮
   ●●●  │ 🔔 3 nouvelles                          │
        │  ✉️ Mail — Adrien : "RDV demain ?"      │
        │  💬 Messages — Maman                    │
        ╰───────────────────────────────────────╯
```

## Fonctionnalités

### Timers / Pomodoro
| Fonction | Détail |
|---|---|
| Minuteur rapide | Presets (5/10/25/60) + saisie perso. |
| Anneau encoche | Progression visible à l'état repos. |
| Pomodoro | Cycles travail/pause configurables, compteur de sessions. |
| Sons / alerte | Son de fin + peek auto + notification système. |
| Plusieurs timers | Optionnel : empiler 2-3 minuteurs nommés. |

### Rappels
| Fonction | Détail |
|---|---|
| Rappel relatif | « dans X min/h ». |
| Rappel absolu | « à HH:MM », « demain 9h ». |
| Saisie naturelle | Optionnel : parser « demain 14h appeler banque ». |
| Persistance | Survivent au redémarrage de l'app. |

### Agrégation de notifications
| Fonction | Détail |
|---|---|
| Capter les notifs | Les afficher dans l'encoche au lieu du coin. |
| Empilement | Grouper par app, compteur. |
| Actions | Ouvrir / ignorer depuis l'encoche. |

> ⚠️ **Capter les notifications système d'autres apps n'a pas d'API publique propre** sous macOS
> (contrairement à iOS). Les approches existantes lisent la base de données des notifications
> (`Notification Center`) — fragile, nécessite des permissions élevées, peut casser à chaque màj.
> → À traiter comme **fonction avancée, optionnelle, désactivée par défaut**, et bien isolée
> pour ne pas compromettre la stabilité du reste. C'est pourquoi elle est planifiée en V4.

## Source des données

- **Timers** : minuterie interne (`Timer` / `DispatchSourceTimer`). Pour l'anneau au repos,
  on n'anime que ce petit anneau — coût négligeable, et on peut le rafraîchir à 1 Hz.
- **Notifications système** : `UNUserNotificationCenter` pour **émettre** nos propres alertes (simple, public).
  Pour **capter celles des autres apps** : lecture du store Notification Center (avancé, fragile — voir avertissement).

## Comportement événementiel (légèreté)

- Pas de timer actif → 0 activité.
- Timer actif → un seul tick par seconde pour l'anneau (négligeable).
- Fin de timer → peek auto + son + notification.

## Paramètres du module

- [ ] Activer Timers / Activer Notifications (séparément)
- [ ] Presets de minuteur (éditables)
- [ ] Réglages Pomodoro (durées, nb de cycles)
- [ ] Afficher l'anneau autour de l'encoche (oui / non) + style
- [ ] Son de fin (choix / volume)
- [ ] Capter les notifs système (avancé, off par défaut) + apps incluses
- [ ] Peek auto en fin de timer (oui / non)

## Cas limites

- **App fermée pendant un timer** → décider : timer perdu, ou relancé au prochain démarrage avec rattrapage.
- **Veille du Mac** → recalculer le temps écoulé au réveil (ne pas faire confiance au compteur de ticks).
- **Plusieurs timers + anneau** → l'anneau suit le timer le plus proche de la fin.
