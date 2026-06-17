# 01 — Concept & modèle d'interaction

## Vision

L'encoche est un « trou noir » matériel que macOS n'exploite pas. Ledge en fait un
**point d'ancrage vivant** : au repos elle reste l'encoche, mais elle s'anime et se déploie
en un menu riche dès qu'on en a besoin. L'app doit donner l'impression d'une **extension
naturelle du matériel**, pas d'une fenêtre posée par-dessus.

## Les 3 états

```
ÉTAT 1 — REPOS                           (par défaut, 99 % du temps)
┌───────────────────────────────────────────────────────────┐
│                      ┌─────────────┐                        │
│  ●●● (barre menu)    │   ENCOCHE   │       (heure, wifi…)    │
│                      └─────────────┘                        │
└───────────────────────────────────────────────────────────┘
   → Rien ne dépasse. Optionnel : 2px d'« activité » sur les bords
     de l'encoche (anneau de timer, spectre audio fin).


ÉTAT 2 — SURVOL / APERÇU                 (souris approche l'encoche)
┌───────────────────────────────────────────────────────────┐
│                ╭───────────────────────────╮                │
│   ●●●         │ ♪  Titre piste —— Artiste   │   (barre menu) │
│               │ [pochette]      ⏱ 04:32     │                │
│                ╰───────────────────────────╯                │
└───────────────────────────────────────────────────────────┘
   → L'encoche "gonfle" en douceur (spring animation).
     Affiche un bandeau compact : aperçus glanés des modules actifs.


ÉTAT 3 — OUVERT                          (clic, ou survol prolongé)
┌───────────────────────────────────────────────────────────┐
│              ╭─────────────────────────────────╮            │
│  ●●●        │  [🎵] [📋] [⚙️] [⏱️]      ⚙ ✕    │  (menu bar) │
│             ├─────────────────────────────────┤            │
│             │                                   │            │
│             │     Contenu du module actif       │            │
│             │     (largeur ~580px)              │            │
│             │                                   │            │
│             ╰─────────────────────────────────╯            │
└───────────────────────────────────────────────────────────┘
   → Panneau complet ancré sous l'encoche, centré.
     Onglets en haut = modules. ⚙ = paramètres. ✕ = fermer.
```

### Transitions

| De → vers | Déclencheur | Animation |
|---|---|---|
| Repos → Survol | curseur entre dans la *hot zone* sous l'encoche | gonflement spring ~0,25 s |
| Survol → Ouvert | clic, OU survol maintenu > délai (réglable) | déroulé vertical du panneau |
| Ouvert → Repos | clic ailleurs, `Échap`, ou curseur sort + délai | rétraction inverse |
| Repos → Survol (auto) | **événement** : nouvelle piste, fin de timer, copie | « peek » bref (2 s) puis retour |

> Le **peek automatique** est ce qui rend l'app vivante : elle vient te montrer une info
> importante sans que tu la sollicites, puis disparaît. À garder discret et réglable (cf. Paramètres).

## La *hot zone*

Zone invisible sous l'encoche qui capte l'entrée du curseur. Doit être :
- légèrement **plus large** que l'encoche (confort) ;
- **dynamique** : calculée à partir de la vraie largeur de l'encoche (`safeAreaInsets`), jamais en dur ;
- désactivable / réglable en sensibilité (cf. [Paramètres](06-ecran-parametres.md)).

## Anatomie de l'état OUVERT

```
╭──────────────────────────────────────────────────────╮
│  ┌────┐                                      ┌──┐┌──┐  │  ← barre d'onglets
│  │ 🎵 │  📋   ⚙️   ⏱️                          │⚙ ││✕ │  │    (module actif surligné)
│  └────┘                                      └──┘└──┘  │
├──────────────────────────────────────────────────────┤
│                                                        │
│   ZONE MODULE (contenu variable selon l'onglet)        │
│                                                        │
│   - hauteur adaptative selon le module                 │
│   - largeur fixe ~580px (réglable : compact / large)   │
│                                                        │
╰──────────────────────────────────────────────────────╯
```

- **Onglets réordonnables** et **masquables** depuis les Paramètres → l'utilisateur compose son menu.
- Possibilité d'un mode « **tout-en-un** » (un seul écran avec sections empilées) vs « **onglets** » (un module à la fois). Choix utilisateur.

## Principes d'UX

1. **Zéro friction au repos** — l'app ne doit jamais gêner. Si tu ne l'invoques pas, elle n'existe pas visuellement.
2. **Réversible** — toute ouverture se ferme par `Échap` / clic extérieur.
3. **Lisible d'un coup d'œil** — l'état Survol doit livrer l'info en < 1 s.
4. **Personnalisable** — modules activables, réordonnables, comportements réglables.
5. **Cohérent avec macOS** — matériaux translucides (`NSVisualEffectView`), coins arrondis qui prolongent l'encoche, respect du mode clair/sombre.

## Détails visuels signature

- Les **coins du panneau** prolongent le rayon de l'encoche → effet « liquide » continu.
- **Matériau** : `.hudWindow` ou `.popover` translucide, ombre douce.
- L'**anneau de timer** et le **spectre audio** peuvent border l'encoche elle-même à l'état repos (very subtle).
