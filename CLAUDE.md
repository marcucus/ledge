# CLAUDE.md — Ledge

App macOS d'encoche (notch) : barre d'outils contextuelle sous l'encoche du MacBook, avec des
modules (Média, Timers, Drop Zone, Presse-papiers, Système, Raccourcis, Calendrier, Notes).
Swift Package Manager pur (pas de projet Xcode), Swift 5.10+, macOS 14+, Apple Silicon.
App `LSUIElement` (pas d'icône Dock, sauf fenêtre Réglages ouverte). Distribution hors App Store
(DMG signé/notarisé + Sparkle) à cause des frameworks privés.

## Commandes

- **Build/test rapide :** `swift build` · `swift test` · `swiftlint lint --quiet <fichiers>`
- **App réelle :** `make app` → `dist/Ledge.app` (signée avec le certificat Apple Development,
  identité stable). C'est le SEUL moyen de tester les **permissions** (Accessibilité, Apple Events,
  Calendrier) : `swift run` n'a pas de bundle/Info.plist, donc macOS (TCC) n'accorde rien.
- **Lancer :** `open dist/Ledge.app`. **Une seule instance à la fois** — sinon plusieurs encoches
  s'ouvrent en parallèle. Avant relance : `killall Ledge`.
- **Distribution :** `make sign` (Developer ID), `make dmg`, `make notarize`, `make appcast`.

## Pièges connus

- **Permissions ⇒ bundle uniquement.** Tester via `dist/Ledge.app`, jamais `swift run`. Le HUD
  volume/luminosité ne supprime l'OSD système que si l'Accessibilité est accordée au bundle.
- **Signature stable.** `make app` signe avec l'identité Apple Development (variable `DEV_SIGN`)
  pour que l'autorisation Accessibilité **persiste entre les rebuilds** (l'ad-hoc la perdait à
  chaque build car le hash changeait).
- **Localisation :** les vraies chaînes UI vivent dans `Sources/Core/Resources/{en,fr}.lproj/`
  `Localizable.strings` (bundle `Ledge_Core`). Celles sous `Sources/App/Resources/*.lproj/` sont
  inertes SAUF `InfoPlist.strings` (permissions), que le Makefile copie à la racine du bundle.

## Conventions de code (référence complète : docs/08-conventions-de-code.md)

- Un type = un fichier ; modules autonomes ne dépendant que de `Core`, jamais l'un de l'autre ;
  API privées derrière un protocole.
- `let` par défaut, **jamais de force-unwrap `!`**, `guard` pour les sorties anticipées,
  `enum` pour les états finis. Fonctions ≤ 30 lignes, fichiers ≤ 400, lignes ≤ 120 colonnes.
- SwiftUI : vues petites, `@Observable` (pas `ObservableObject`), aucune logique métier dans le
  `body`, constantes nommées (zéro littéral magique).
- `@MainActor` pour l'UI. Nommage : **anglais pour le code, français pour l'UI/doc**. Booléens en
  question (`isExpanded`), fonctions en verbe.
- Commentaires : le *pourquoi*, pas le *quoi* ; marquer les API privées (`// PRIVATE API`).
- **Avant de déclarer une tâche finie :** `swift build` + `swiftlint lint` (sans nouveau warning)
  + `swift test` verts, et un lancement réel (`make app` + `open`) qui ne plante pas.

## Architecture & extension

- `Core` (fenêtre/encoche, états, réglages, ModuleKit) + un package par module sous
  `Sources/Modules/<Nom>/`. Contrat des modules : `NotchModule`. Pour brancher un module : 3 points
  d'assemblage (Package.swift, ModuleCatalog, AppDelegate). **Détail complet :
  docs/11-extensibilite-modules.md.** Pas de chargement dynamique de plugins tiers (sécurité).
- État de la fenêtre : `NotchController` (machine à états `collapsed/ambient/peeking/hud/expanded`).
  Contributions « ambient » (pills à côté de l'encoche) via `setAmbient(_:sourceID:priority:)`.

## Contraintes produit

- **Natif d'abord.** Aucune dépendance tierce sans justification écrite.
- **Échoue proprement.** Toute fonction sur API privée/permission se dégrade sans planter.
- **Rien ne tourne au repos.** Événementiel par défaut (listeners CoreAudio, etc.) ; le polling
  est borné et arrêté panneau fermé.
- **Confidentialité.** Historique presse-papiers en RAM par défaut (persistance = opt-in explicite).
- **i18n dès le départ.** Aucun texte affiché en dur ; tout via `Localizable.strings` (FR + EN).

## Façon de travailler

Explications en **français**, concises, à destination d'un dev débutant en Swift. Minimum de
lignes, maximum de clarté ; supprimer avant d'ajouter. Quand un choix a des alternatives, donner
**une recommandation**, pas un catalogue. Ne jamais contredire la doc sans le signaler d'abord.

> Plan, audit et suivi des jalons : docs/10-audit-et-plan.md.
