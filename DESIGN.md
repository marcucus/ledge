---
name: Ledge
description: Une extension noire, précise et vivante de l’encoche du Mac.
colors:
  notch-black: "#000000"
  optical-graphite: "#101315"
  ink-primary: "#F0EFEA"
  spectral-violet: "#8B6FF7"
typography:
  title:
    fontFamily: "SF Pro, -apple-system, sans-serif"
    fontSize: "20px"
    fontWeight: 600
    lineHeight: 1.2
  body:
    fontFamily: "SF Pro, -apple-system, sans-serif"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: 1.4
  label:
    fontFamily: "SF Pro, -apple-system, sans-serif"
    fontSize: "9px"
    fontWeight: 500
    lineHeight: 1.2
rounded:
  control: "10px"
  surface: "14px"
  panel-user: "4px–24px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "10px"
  lg: "14px"
components:
  notch-panel:
    backgroundColor: "{colors.notch-black}"
    textColor: "{colors.ink-primary}"
    rounded: "{rounded.panel-user}"
  layout-choice:
    backgroundColor: "{colors.optical-graphite}"
    textColor: "{colors.ink-primary}"
    rounded: "{rounded.control}"
    padding: "10px"
---

# Design System: Ledge

## Overview

**Creative North Star: « Le banc optique »**

Ledge doit paraître usiné avec le Mac plutôt qu’affiché par-dessus lui. La matière noire de
l’encoche se prolonge dans la navigation puis dans le contenu ; le graphite, les coutures fines et
un accent spectral rare rendent les états lisibles sans casser cette continuité.

L’interface est calme au repos et précise en action. Les trois dispositions Concentrée,
Panoramique et Immersive modifient la géométrie, jamais l’identité ni le comportement fondamental.

**Caractéristiques clés :**

- noir continu avec l’encoche et la barre des menus ;
- violet réservé à la sélection, la progression et l’état actif ;
- hiérarchie par l’espace, les traits et la typographie plutôt que par des cartes empilées ;
- mouvement unique d’expansion et de résorption depuis l’axe de l’encoche.

## Colors

La palette est volontairement restreinte : deux noirs, un blanc chaud et un accent configurable.

### Primary

- **Noir encoche** (`#000000`) : fond permanent du panneau et continuité matérielle avec le Mac.
- **Violet spectral** (`#8B6FF7`) : valeur de référence pour les aperçus ; en production, la couleur
  d’accent choisie par l’utilisateur remplit ce rôle.

### Neutral

- **Graphite optique** (`#101315`) : séparation tonale des réglages et surfaces secondaires.
- **Encre chaude** (`#F0EFEA`) : texte et pictogrammes prioritaires sur fond noir.

**Règle du signal rare.** L’accent indique un état ou une progression ; il ne remplit jamais le
panneau et ne remplace pas la hiérarchie.

## Typography

**Display Font:** SF Pro, fourni par macOS  
**Body Font:** SF Pro, fourni par macOS

La typographie reste native pour conserver la netteté, l’accessibilité et la cohérence avec les
contrôles AppKit et SwiftUI. La personnalité vient des proportions, de l’espace et du mouvement,
pas d’une police décorative.

### Hierarchy

- **Title** (semibold, 20 pt) : titre d’un module ou d’une page de réglages.
- **Body** (regular, 12–13 pt) : contenu et explication.
- **Label** (medium, 9–10 pt) : libellé court de module ou métadonnée secondaire.
- **Data** : chiffres en `monospacedDigit()` uniquement lorsque l’alignement change dans le temps.

## Layout

Le panneau est centré sur l’encoche et reste physiquement attaché au bord supérieur de l’écran.
Panoramique est la disposition recommandée (`920 × 278 pt` environ avec navigation), Concentrée
resserre le panneau à `580 pt`, et Immersive utilise `744 pt` avec davantage de hauteur. Les modules
se répartissent sur les deux épaules de l’encoche dans les dispositions larges.

Le rythme principal repose sur 4, 8, 10 et 14 points. Une information principale domine chaque
module ; les contrôles secondaires restent alignés sur des coutures ou des axes communs.

## Elevation & Depth

La profondeur est tonale. Le panneau n’emploie ni ombre décorative ni halo : noir et graphite sont
séparés par des traits blancs de 0,5 à 1 point et une seule marche d’élévation lorsque nécessaire.

**Règle du plan continu.** Une nouvelle fonction rejoint la surface existante avant de demander un
conteneur supplémentaire.

## Shapes

`NotchPanelShape` est la silhouette signature. Ses oreilles hautes prolongent la barre des menus et
ses coins bas restent continus. Le rayon utilisateur varie de 4 à 24 points ; les contrôles internes
emploient généralement 10 à 14 points. Les capsules sont réservées aux indicateurs fins et aux
sélections, jamais aux grands conteneurs.

## Components

### Navigation des modules

Les icônes SF Symbols vivent seules sur les épaules de l'encoche afin de préserver leur rythme,
quelle que soit la langue. Les noms restent disponibles dans VoiceOver et dans la grille. L'état
actif combine encre pleine, fond tonal discret et trait d'accent de 2 points. Le survol ne modifie
que la luminosité et le fond tonal.

### Sélecteur de disposition

Trois choix persistants présentent un nom, une explication et un aperçu fidèle. La sélection utilise
un trait d’accent de 1,5 point ; Panoramique porte le libellé « recommandé » sans bloquer les autres.

### Panneau Ledge

Le fond reste noir avec une opacité comprise entre 92 et 100 %. L’ouverture dure environ 460 ms,
la fermeture 320 ms, avec un amortissement rapide. « Réduire les animations » supprime le déplacement
et conserve un changement d’état immédiat et lisible.

## Do's and Don'ts

### Do:

- **Do** partir de l’encoche pour toute géométrie ou transition du panneau.
- **Do** réserver l’accent à une information active, sélectionnée ou progressive.
- **Do** vérifier chaque disposition avec les modules visuels et les modules textuels.
- **Do** conserver les libellés VoiceOver et une variante sans mouvement.

### Don't:

- **Don't** introduire un fond clair dans le panneau sous l’encoche.
- **Don't** détacher une toolbar, une popover ou une carte du bord supérieur de l’écran.
- **Don't** empiler des cartes arrondies quand un trait ou un espacement suffit.
- **Don't** utiliser du glow, un dégradé décoratif ou plusieurs accents simultanés.
