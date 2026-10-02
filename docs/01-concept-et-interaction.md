# 01 — Concept & modèle d'interaction

> **Statut 0.3.0 : contrat produit actif.** Les cinq états livrés sont `collapsed`, `ambient`,
> `peeking`, `hud` et `expanded`. Les idées non présentes dans le code restent de la vision et ne
> constituent pas des promesses de la candidate ; voir [doc 09](09-avancement-et-contexte.md).

## Vision

L'encoche est un « trou noir » matériel que macOS n'exploite pas. Ledge en fait un
**point d'ancrage vivant** : au repos elle reste l'encoche, mais elle s'anime et se déploie
en un menu riche dès qu'on en a besoin. L'app doit donner l'impression d'une **extension
naturelle du matériel**, pas d'une fenêtre posée par-dessus.

## Les états d'interaction principaux

```
ÉTAT 1 — REPOS                           (par défaut, 99 % du temps)
┌───────────────────────────────────────────────────────────┐
│                      ┌─────────────┐                        │
│  ●●● (barre menu)    │   ENCOCHE   │       (heure, wifi…)    │
│                      └─────────────┘                        │
└───────────────────────────────────────────────────────────┘
   → Rien ne dépasse. Optionnel : 2px d'« activité » sur les bords
     de l'encoche (anneau de timer, spectre audio fin).


ÉTAT 2 — AMBIENT / APERÇU                (événement utile ou clic configuré)
┌───────────────────────────────────────────────────────────┐
│                ╭───────────────────────────╮                │
│   ●●●         │ ♪  Titre piste —— Artiste   │   (barre menu) │
│               │ [pochette]      ⏱ 04:32     │                │
│                ╰───────────────────────────╯                │
└───────────────────────────────────────────────────────────┘
   → L'encoche s'étend discrètement pour une information temporaire.
     L'état compact n'est pas une étape obligatoire avant l'ouverture.


ÉTAT 3 — OUVERT                          (survol direct ou clic)
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
| Repos / Ambient → Ouvert | curseur entre dans la *hot zone* ou action d'ouverture | expansion directe du panneau |
| Ouvert → Repos | clic ailleurs, `Échap`, ou curseur sort + délai | rétraction inverse |
| Repos → Ambient / HUD | **événement** : média, timer, drag, volume ou luminosité | extension compacte puis retour |
| Repos → Aperçu | clic si le comportement « Aperçu » est sélectionné | barre compacte explicite |

> Le survol ouvre directement le panneau complet. Cette décision produit est volontaire : aucun
> délai ni aperçu intermédiaire ne doit ralentir l'accès aux modules.

## La *hot zone*

Zone invisible sous l'encoche qui capte l'entrée du curseur. Elle est :
- légèrement **plus large** que l'encoche (confort) ;
- **dynamique** : calculée à partir de la vraie largeur de l'encoche (`safeAreaInsets`), jamais en dur ;
- réglable sur trois tailles : Précise, Standard ou Large (cf. [Paramètres](06-ecran-parametres.md)).

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
3. **Lisible d'un coup d'œil** — l'ambient et le HUD doivent livrer l'information en < 1 s.
4. **Personnalisable** — modules activables, réordonnables, comportements réglables.
5. **Cohérent avec le matériel** — surface noire continue, coins arrondis qui prolongent l'encoche et respect de « Réduire les animations ».

## Détails visuels signature

- Les **coins du panneau** prolongent le rayon de l'encoche → effet « liquide » continu.
- **Matériau** : noir continu avec l'encoche, sans ombre décorative ni rupture de surface.
- L'**anneau de timer** et le **spectre audio** peuvent border l'encoche elle-même à l'état repos (very subtle).
