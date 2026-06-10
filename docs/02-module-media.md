# 02 — Module Média 🎵

> Le module « waouh » et le plus simple à brancher → **premier à implémenter (V1)**.

## Objectif

Contrôler ce qui joue actuellement (n'importe quelle source : Apple Music, Spotify,
YouTube dans Safari/Chrome, podcasts…) directement depuis l'encoche, avec la pochette
qui « déborde » du matériel — la signature visuelle de l'app.

## Wireframes

### État Survol (aperçu compact)

```
        ╭───────────────────────────────────────╮
       │ ┌──────┐                                 │
  ●●●  │ │ POCH │  Blinding Lights                │  menu bar
       │ │ ETTE │  The Weeknd          ▸ ❚❚      │
       │ └──────┘  ▁▂▃▅▇▅▃▂  (spectre)            │
        ╰───────────────────────────────────────╯
```
- La pochette « sort » à gauche de l'encoche (effet débordement).
- Spectre audio animé OU barre de progression fine.
- 1 bouton lecture/pause accessible direct.

### État Ouvert (contrôle complet)

```
╭──────────────────────────────────────────────────────╮
│  🎵  📋  ⚙️  ⏱️                              ⚙   ✕    │
├──────────────────────────────────────────────────────┤
│                                                        │
│     ┌────────────┐    Blinding Lights                  │
│     │            │    The Weeknd                       │
│     │  POCHETTE   │    After Hours · 2020               │
│     │            │                                      │
│     └────────────┘    ♥  Ajouter aux favoris           │
│                                                        │
│   01:12 ●━━━━━━━━━━━━━━━━━━━━━━━━━━━ 04:32              │
│                                                        │
│            ⏮      ⏯  (grand)      ⏭                    │
│                                                        │
│   🔊 ──────●──────────   📻 AirPlay ▾   Source: Spotify │
╰──────────────────────────────────────────────────────╯
```

## Fonctionnalités

| Fonction | Détail |
|---|---|
| Now Playing | Titre, artiste, album, pochette en haute résolution. |
| Transport | Play / pause / précédent / suivant. |
| Scrubbing | Barre de progression cliquable/draggable. |
| Volume | Slider (volume système ou app selon la source). |
| AirPlay | Liste des sorties audio, changement rapide. |
| Favori | ♥ si la source le supporte (Apple Music, Spotify via API). |
| Spectre / progression | Visualisation fine, affichable même à l'état repos (bordure encoche). |

## Source des données

- **`MediaRemote.framework`** (privé mais largement utilisé par ce type d'app) :
  expose le « Now Playing » de **toute** app qui publie ses infos média à macOS.
  - `MRMediaRemoteGetNowPlayingInfo` → métadonnées + pochette.
  - `MRMediaRemoteRegisterForNowPlayingNotifications` → **événements** (pas de polling).
  - `MRMediaRemoteSendCommand` → play/pause/next/prev/seek.
- ⚠️ Framework privé → risque de cassure entre versions de macOS. Prévoir une couche
  d'abstraction `MediaSource` pour pouvoir basculer sur une alternative (MediaPlayer public, scripting Spotify) si besoin.

## Comportement événementiel (légèreté)

- On **s'abonne** aux notifications de changement de piste/état → **0 polling**.
- Pochette mise en cache (évite de la recharger).
- Spectre audio animé **uniquement** quand le panneau est visible (survol/ouvert).
- Au repos : aucune activité CPU.

## Paramètres du module (cf. [06](06-ecran-parametres.md))

- [ ] Activer le module Média
- [ ] Peek auto au changement de piste (oui / non)
- [ ] Durée du peek (1–5 s)
- [ ] Visualisation : spectre / barre de progression / aucune
- [ ] Afficher la visualisation à l'état repos (bordure encoche)
- [ ] Taille de la pochette débordante (S / M / L)
- [ ] Sources autorisées (toutes / liste blanche d'apps)

## Cas limites

- **Rien ne joue** → module masqué de l'aperçu, ou état « Aucune lecture ».
- **Plusieurs sources actives** → suivre la dernière active, avec sélecteur de source.
- **Source sans pochette** → placeholder + couleur dominante dérivée.
- **DRM / pochette protégée** → fallback icône de l'app source.
