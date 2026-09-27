---
version: 1
slug: "sources-core-notchwindow-notchcontentview-swift"
primary_target: "Sources/Core/NotchWindow/NotchContentView.swift"
related_targets: ["Sources/App/Settings/SettingsRootView.swift"]
---

# Ledge application surface

Mode: operate. Scope: panneau sous l’encoche et fenêtre Réglages. Le comportement fonctionnel,
les modules, la localisation, VoiceOver et « Réduire les animations » restent intacts.

## Direction contract

**THESIS** — Ledge est un banc optique noir qui se matérialise depuis l’encoche. Il refuse la
collection de cartes flottantes et le formulaire macOS générique : navigation, contenu et états
partagent un seul plan continu.

**OWN-WORLD** — Noir profond permanent pour rejoindre la vraie encoche, graphite pour séparer les
plans, texte blanc cassé et violet spectral réservé à l’action ou à l’état actif. Les coutures sont
des traits fins ; les coins prolongent exactement la géométrie de l’encoche. Aucun effet ne doit
donner l’impression d’une fenêtre déposée sous la barre des menus.

**STORY** — Au repos, seule l’encoche existe. Un survol ou un événement étire sa matière noire ; le
module utile devient immédiatement lisible, l’utilisateur agit, puis le panneau se résorbe dans la
barre des menus sans rupture visuelle.

**FIRST VIEWPORT** — La disposition Panoramique sert de référence : les deux ailes noires prolongent
l’encoche, portent la navigation et ouvrent un contenu horizontal ample. Les Réglages reprennent
cette matière avec une sidebar claire et un aperçu vivant dominant. Deux variantes sélectionnables
conservent exactement ce langage : Concentrée resserre le contenu sous l’encoche ; Immersive donne
le premier tiers au contenu visuel.

**FORM** — Direction « Le banc optique », candidate 4 de la liste ancrée, seed `a62684ef`.
Interaction signature : une expansion organique attachée à l’encoche et à la barre des menus,
rapide au départ puis amortie, avec une variante sans déplacement pour « Réduire les animations ».

**FINISH** — unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Unresolved

Les trois compositions sont des dispositions utilisateur d’une même identité. Panoramique est le
choix recommandé par défaut. Concentrée et Immersive restent sélectionnables dans Apparence. Le
noir continu et la continuité animée avec l’encoche sont non négociables dans chaque disposition.
