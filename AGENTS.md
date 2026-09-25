# Mémoire de projet — Ledge (application macOS)

Ce fichier est le contexte opérationnel durable du dépôt. Il complète `CLAUDE.md` sans le
remplacer. Les échanges avec Adrien se font en français, avec des explications accessibles à un
développeur débutant en Swift.

## Avant toute modification

1. Lire `CLAUDE.md`.
2. Lire la documentation directement liée à la tâche dans `docs/`.
3. Pour connaître l'état du produit, lire en priorité `docs/09-avancement-et-contexte.md` et
   `docs/10-audit-et-plan.md`, puis vérifier le code : ces documents sont des instantanés et peuvent
   dater.
4. Si la tâche touche le site, lire aussi `PROMPT-SITE-WEB.md` et le fichier
   `../ledge-site/AGENTS.md`.
5. Inspecter `git status` avant d'éditer et préserver les changements existants.

## Hiérarchie des sources de vérité

- Le code, `Package.swift`, `Sources/App/Info.plist`, le `Makefile` et les tests décrivent l'état
  exécutable actuel.
- `docs/09` et `docs/10` décrivent l'avancement, mais leurs dates et leurs tableaux de suivi ne
  dispensent jamais de vérifier le code.
- `docs/01` à `docs/08` décrivent surtout la vision produit, les comportements attendus et les
  conventions.
- `docs/11` décrit le contrat d'extension interne `NotchModule`.
- `docs/PROMPT_IA.md` est historique et obsolète : il emploie encore le nom « Notchy » et ne doit
  pas primer sur `CLAUDE.md` ou ce fichier.
- En cas de contradiction, ne pas la masquer : signaler l'écart et mettre à jour la documentation
  concernée dans la même tâche lorsque c'est pertinent.

## Produit et architecture actuels

- Ledge transforme l'encoche du MacBook en panneau modulaire natif, discret au repos.
- Stack : Swift Package Manager, Swift 5.10+, AppKit pour la fenêtre, SwiftUI pour le contenu,
  Sparkle pour les mises à jour.
- La cible effective est **macOS 14+** (`Package.swift` et `Info.plist`). Les mentions macOS 13+
  encore présentes dans d'anciens documents ou sur le site sont obsolètes tant que les manifests
  ne changent pas.
- Les cinq états réels sont `collapsed`, `ambient`, `peeking`, `hud` et `expanded`.
- Huit modules sont compilés : Média, Timers, Drop Zone, Presse-papiers, Système, Raccourcis,
  Calendrier et Notes.
- Sept modules sont actuellement enregistrés comme onglets. Le module Système est volontairement
  masqué de la navigation dans `AppDelegate`, mais reste démarré comme source de statut et de HUD.
- Le cœur vit dans `Sources/Core`; chaque module est une cible autonome sous `Sources/Modules` et
  ne dépend que de `Core`.
- Les contributions ambient sont arbitrées par priorité dans `NotchController` : Média 3,
  Timers 2, Drop Zone 1.
- Les réglages sont centralisés dans `SettingsStore`; les profils par application peuvent
  remplacer l'ordre et l'activation globale des modules.
- Les textes UI effectifs sont localisés en anglais et en français dans
  `Sources/Core/Resources/{en,fr}.lproj/Localizable.strings`. Les ressources App servent surtout à
  `InfoPlist.strings`.

## Invariants à préserver

- Rien de coûteux ne tourne au repos. Préférer les événements système; tout polling doit être
  justifié, borné et arrêté dès qu'il n'est plus nécessaire.
- Les API privées et les permissions sont isolées derrière des abstractions et échouent sans
  planter l'application.
- L'historique du presse-papiers reste en RAM par défaut; la persistance disque est un opt-in.
- Aucun texte visible en dur. Toute nouvelle chaîne doit être ajoutée en anglais et en français.
- Aucun force-unwrap de production, aucun état global mutable supplémentaire, aucun couplage entre
  modules.
- Un type principal par fichier, noms anglais dans le code, documentation et explications en
  français.
- Tester les permissions uniquement avec le bundle construit par `make app`; `swift run` ne
  représente pas le comportement TCC réel.
- Une seule instance de Ledge doit tourner pendant les essais manuels.

## Commandes de référence

```bash
swift build
swift test
swiftlint lint --quiet Sources Tests
make app
open dist/Ledge.app
```

Avant une relance manuelle, arrêter l'instance existante avec `killall Ledge`. Les changements de
distribution se vérifient aussi avec les cibles `make sign`, `make dmg`, `make notarize` et
`make appcast` selon les secrets disponibles.

## État vérifié le 24 septembre 2026

- Branche `main`, commit observé `fa5f726`.
- `swift test` compile et exécute **27 tests dans 4 suites**, tous verts.
- SwiftLint est vert sur `Sources` et `Tests` au 24 septembre 2026.
- Version bundle actuelle : `0.1.0`.
- La clé publique Sparkle est renseignée. `SUFeedURL` est injectée dans le bundle de distribution
  par `SPARKLE_FEED_URL`; le bundle de développement n'active pas Sparkle sans cette valeur.
- `make release` crée un DMG signé ad hoc, génère l'appcast Sparkle EdDSA, crée une GitHub Release
  brouillon, téléverse les deux fichiers puis la publie. Aucun compte Apple, bucket ou service
  payant n'est requis. Le parcours Developer ID reste optionnel via `make release-notarized`.
- Les fonctionnalités Apple Music et les permissions doivent être validées dans une vraie lecture
  et un bundle signé; les tests unitaires ne couvrent pas ce scénario système.

## Contrat avec `ledge-site`

- Le site est le canal prévu pour publier et télécharger le DMG; il vit dans le dépôt frère
  `../ledge-site`.
- `make release` appelle `Scripts/publish-release.sh` avec un token GitHub fin limité au dépôt et à
  `Contents: write`. Le script utilise `GITHUB_TOKEN` s'il est fourni, sinon l'entrée du Trousseau
  macOS `dev.ledge.github-release-token`. Le token ne doit jamais être commité ni déployé avec le
  site.
- `SUFeedURL` pointe par défaut vers l'asset `appcast.xml` de la dernière GitHub Release stable.
  Les DMG et appcasts sont des assets de release, jamais des fichiers suivis par Git.
- Les promesses du site doivent suivre le code réel : macOS 14+, modules réellement visibles,
  permissions réellement requises, version publiée réelle et limites connues.

## Fin de tâche

- Exécuter les vérifications proportionnées au changement.
- Pour du code Swift : au minimum build, tests et SwiftLint; signaler précisément toute dette déjà
  présente.
- Mettre à jour `docs/09` ou `docs/10` lorsqu'une modification change l'état réel, les limites ou
  le plan.
- Si le contrat de publication, la compatibilité ou le discours produit change, synchroniser aussi
  `ledge-site` ou consigner explicitement l'écart restant.
