# 06 — Écran Paramètres

> Le centre de contrôle de l'app. L'utilisateur y compose son menu (modules actifs, ordre,
> comportements) et règle les 4 choix critiques (multi-écran, plein écran, permissions, encoche).

## Forme

Fenêtre de réglages **classique macOS** (pas dans l'encoche) — une vraie `NSWindow`
avec une **sidebar** à gauche et le détail à droite. Accessible via l'icône ⚙ du panneau
ou un raccourci global.

```
╭───────────────────────────────────────────────────────────────╮
│  Notchy — Réglages                                       — ☐ ✕  │
├──────────────────┬────────────────────────────────────────────┤
│ ▸ Général         │                                            │
│ ▸ Apparence       │      [ Contenu de la section sélectionnée ] │
│ ▸ Modules         │                                            │
│   · Média         │                                            │
│   · Presse-papiers│                                            │
│   · Système       │                                            │
│   · Timers        │                                            │
│ ▸ Affichage       │   (multi-écran, plein écran, encoche)       │
│ ▸ Permissions     │                                            │
│ ▸ Raccourcis      │                                            │
│ ▸ À propos        │                                            │
╰──────────────────┴────────────────────────────────────────────╯
```

---

## Section « Général »

```
GÉNÉRAL
  ☑ Lancer au démarrage de session
  ☑ Masquer l'icône du Dock (mode agent)
  Sensibilité de la hot zone     [—————●———]  (petite ↔ large)
  Délai d'ouverture au survol     [ 0,4 s ▾ ]
  ☑ Peek automatique sur événement (global)
       Durée du peek              [ 2 s ▾ ]
  Langue                          [ 🌐 Système (Français) ▾ ]
       └─ Système · Français · English · Español · Deutsch · …
  [ Réinitialiser tous les réglages ]
```

### Langue — comportement

- **Au premier lancement**, l'app suit **automatiquement la langue du Mac** (réglages système).
- Le sélecteur propose **« Système »** (= suivre le Mac, valeur par défaut) **+ la liste des
  langues fournies** par l'app.
- Choisir une langue ici **force** cette langue pour Notchy, indépendamment du système.
- Le changement s'applique **immédiatement** (pas besoin de redémarrer l'app) : tous les
  textes des panneaux et des réglages se mettent à jour à la volée.
- Détails techniques (chargement des `.lproj`, `Localizable`, override de langue) → cf.
  [Architecture → Internationalisation](07-architecture-technique.md#internationalisation-i18n).

---

## Section « Apparence »

```
APPARENCE
  Thème                  ( ) Clair  ( ) Sombre  (•) Système
  Matériau du panneau    [ Translucide HUD ▾ ]
  Largeur du panneau     ( ) Compact  (•) Standard  ( ) Large
  Disposition            (•) Onglets (un module)  ( ) Tout-en-un (empilé)
  Coins                  [—————●——]  (rayon, prolonge l'encoche)
  ☑ Effets de débordement (pochette, anneau)
  Densité                ( ) Confort  (•) Standard  ( ) Dense
```

---

## Section « Modules » — composer son menu

C'est ici que l'utilisateur **active, réordonne et masque** les modules. L'ordre ici =
l'ordre des onglets dans l'encoche.

```
MODULES                       (glisser pour réordonner)
  ☰  🎵  Média            [ON ]   ⚙ Configurer →
  ☰  ⏱️  Timers           [ON ]   ⚙ Configurer →
  ☰  📋  Presse-papiers   [OFF]   ⚙ Configurer →
  ☰  ⚙️  Système          [ON ]   ⚙ Configurer →

  + Modules futurs apparaîtront ici
```

Chaque « Configurer → » ouvre les réglages détaillés du module (listés dans les docs
[02](02-module-media.md), [03](03-module-presse-papiers-dropzone.md),
[04](04-module-systeme.md), [05](05-module-timers-notifications.md)).

---

## Section « Affichage » — TES 3 CHOIX 1, 2, 4

### Choix 1 — Multi-écran / écran sans encoche

```
AFFICHAGE — Écrans
  Sur quel écran afficher Notchy ?
     (•) Écran avec l'encoche (intégré)
     ( ) Écran principal (celui de la barre de menu)
     ( ) Écran où se trouve le curseur
     ( ) Tous les écrans

  Sur un écran SANS encoche :
     (•) Afficher une "pseudo-encoche" en haut au centre
     ( ) Afficher un petit onglet discret
     ( ) Ne rien afficher
```

> Par défaut on suit l'écran intégré (vraie encoche). La pseudo-encoche permet d'avoir
> l'expérience sur un moniteur externe. La largeur/forme de la pseudo-encoche est réglable.

### Choix 2 — Comportement en plein écran

```
AFFICHAGE — Plein écran
  Quand une app est en plein écran (barre de menu masquée) :
     (•) Rester accessible (apparaît au survol du haut de l'écran)
     ( ) Se masquer automatiquement
     ( ) Rester visible en permanence (overlay)

  ☑ Garder l'anneau de timer visible même en plein écran
  ☑ Autoriser les peek auto en plein écran
```

> Le plein écran masque la barre de menu et change les insets → c'est un cas à gérer
> explicitement. On laisse l'utilisateur décider de l'intrusivité.

### Choix 4 — Détection de l'encoche (dynamique, jamais en dur)

```
AFFICHAGE — Encoche
  Détection                (•) Automatique (recommandé)
                           ( ) Manuelle (régler la position/taille)

  ── Mode automatique ──
     Encoche détectée : largeur 180 pt · hauteur 32 pt  ✓
     [ Re-détecter ]

  ── Mode manuel (Mac sans encoche / réglage fin) ──
     Largeur   [——●———]      Hauteur   [—●————]
     Décalage horizontal [——●——]   Aperçu en direct ▢
```

> **Aucune valeur codée en dur.** En auto, on lit `screen.safeAreaInsets` +
> `auxiliaryTopLeft/RightArea` pour déduire la géométrie réelle de l'encoche (variable selon
> le modèle de Mac). Le mode manuel sert de filet (modèle non reconnu, pseudo-encoche externe).

---

## Section « Permissions » — TON CHOIX 3

Tableau de bord des autorisations, avec **statut en direct** et bouton pour les accorder.
On ne demande **que** ce dont les modules activés ont besoin.

```
PERMISSIONS
  État des autorisations requises par tes modules actifs :

  🔔 Notifications          ✅ Accordée        [ Gérer ]
       → alertes de fin de timer
  📋 Presse-papiers         ✅ Implicite       —
       → historique de copies
  ♿ Accessibilité          ⚠️ Requise         [ Ouvrir Réglages ]
       → certains toggles système (dark mode, focus)
  🤖 Automation             ❌ Non accordée    [ Demander ]
       → contrôler des apps (AppleScript)
  🔕 Notifications d'autres apps  ⚠️ Avancé    [ En savoir + ]
       → capter les notifs système (fragile, optionnel)

  ☑ Ne demander une permission qu'au moment où la fonction est utilisée
```

> Principe : **demande paresseuse et contextuelle**. À la première utilisation d'une fonction
> qui requiert une permission, on l'explique puis on la demande. Cette page récapitule tout
> et permet de re-déclencher. Voir détails dans [Architecture](07-architecture-technique.md).

---

## Section « Raccourcis »

```
RACCOURCIS CLAVIER GLOBAUX
  Ouvrir / fermer le panneau     [ ⌃ Espace ]   [ ✎ ]
  Module Média                   [ non défini ] [ ✎ ]
  Nouveau minuteur               [ ⌥⌘ T      ]  [ ✎ ]
  Coller depuis l'historique     [ ⌥⌘ V      ]  [ ✎ ]
  Drop Zone                      [ non défini ] [ ✎ ]
```

---

## Section « À propos »

Version, lien réglages, réinitialisation, licence, crédits, vérif. de mise à jour.

---

## Récap des 4 choix critiques → tous dans Paramytres

| # | Choix | Section | Défaut |
|---|---|---|---|
| 1 | Multi-écran / écran sans encoche | Affichage → Écrans | Écran intégré + pseudo-encoche externe |
| 2 | Comportement en plein écran | Affichage → Plein écran | Accessible au survol |
| 3 | Permissions | Permissions | Demande paresseuse contextuelle |
| 4 | Détection de l'encoche | Affichage → Encoche | Automatique (jamais en dur) |
