# 13 — Audit de finalisation de Ledge

> État consolidé le **30 septembre 2026** après les jalons 1 à 4, la refonte de `ledge-site` et
> l'ajout de la couche juridique.
>
> Version publique : `0.2.0` (build `2`). Candidate locale : `0.3.0` (build `3`).

## Verdict

Ledge possède désormais le périmètre fonctionnel nécessaire à une nouvelle version publique :
machine à états stable, trois compositions, sept modules visibles, sources Système et HUD,
réglages complets, onboarding, localisation français/anglais, Sparkle et distribution par GitHub
Releases.

Les jalons fonctionnels 1 à 4 sont clos dans le code. La fin du projet ne demande plus d'ajouter
les anciennes idées de la vision historique ; elle demande une recette réelle, de l'automatisation
et la correction des défauts observés pendant cette recette.

## Décisions produit qui ne doivent plus être remises en question

- Le survol ouvre directement le panneau complet : aucun délai ni aperçu compact intermédiaire.
- Une seule cible d'écran est choisie ; un écran sans encoche reçoit la pseudo-encoche.
- Les trois compositions gardent un fond noir raccordé à l'encoche.
- Le module Système reste volontairement absent de la navigation. Il fournit batterie, HUD et
  signaux système en arrière-plan sans présenter un onglet incomplet.
- Le presse-papiers reste en RAM par défaut. Sa persistance est un opt-in chiffré.
- Un module désactivé est réellement arrêté avec `stop()`.
- Les fonctionnalités sans API publique fiable restent hors périmètre : agrégation des
  notifications, météo, Focus, AirDrop entrant, codes 2FA et plugins dynamiques tiers.

## État technique vérifié

| Vérification | Résultat |
|---|---|
| `swift build` | ✅ Succès |
| `swift test` | ✅ 95 tests dans 14 suites |
| `swiftlint lint --quiet Sources Tests` | ✅ Aucune erreur |
| `make app` | ✅ Bundle construit et signé avec l'identité de développement |
| Licence Sparkle | ✅ Copie exacte incluse dans les ressources du bundle |
| Localisation | ✅ Nouvelles chaînes juridiques présentes en français et en anglais |
| Version locale | ✅ `0.3.0` — build `3` |

Deux avertissements SwiftLint historiques subsistent : `SettingsStore.swift` et
`NotchController.swift` dépassent 400 lignes sans atteindre le seuil d'erreur de 500 lignes.

## Jalons terminés

### Jalon 1 — Interactions centrales

- fermeture par Échap et clic extérieur ;
- zone chaude configurable ;
- ouverture directe au survol conservée ;
- politiques plein écran Accessible, Masqué et Overlay ;
- progression réelle du timer sans animation permanente.

### Jalon 2 — Cycle de vie et confidentialité

- `start()` et `stop()` suivent l'activation globale et les profils par application ;
- un presse-papiers désactivé ne capture plus ;
- réglages trompeurs du module Système retirés ;
- erreurs de persistance du presse-papiers visibles et récupérables.

### Jalon 3 — Fiabilité des modules

- ancrage du partage Drop Zone corrigé ;
- collisions de noms gérées à la copie ;
- identité explicite de la source Média ;
- historique persistant du presse-papiers chiffré avec clé Keychain ;
- exclusions d'applications et collage en texte brut ;
- timers persistants et peek de fin configurable.

### Jalon 4 — Accessibilité et réglages

- progression Média ajustable avec VoiceOver ;
- molettes Timer accessibles ;
- Quick Look au clavier et via VoiceOver ;
- erreur de lancement à la connexion affichée ;
- réinitialisation complète des réglages ;
- localisation du libellé Système.

## Jalon 5 — Qualité et recette de `0.3.0`

### Automatisation

- [x] Ajouter une CI GitHub Actions pour build, tests et SwiftLint.
- [ ] Valider la CI sur la branche distante.
- [x] Ajouter des tests dédiés pour App, Calendrier, Notes et Raccourcis.
- [ ] Étudier des tests d'intégration pour fenêtres, plein écran et écrans externes.

### Recette manuelle

- [ ] Tester Apple Music et Spotify seuls puis simultanément.
- [ ] Valider pochette Apple Music, seek et permission Automation.
- [ ] Tester les trois politiques plein écran et les changements d'espace.
- [ ] Tester écran interne, écran externe, déconnexion et reconnexion.
- [ ] Tester veille/réveil avec timer actif.
- [ ] Effectuer une passe VoiceOver et Réduire les animations.
- [ ] Mesurer CPU et RAM au repos, pendant un timer et pendant une lecture média.
- [ ] Tester Gatekeeper sur un autre Mac.
- [ ] Tester la mise à jour Sparkle `0.2.0` → `0.3.0` sur un autre Mac.

La procédure détaillée vit dans [doc 12](12-recette-release-candidate.md).

### Site et publication

- [x] Faire correspondre les visuels du site aux captures natives de l'app.
- [x] Ajouter mentions légales, confidentialité, conditions et licences tierces.
- [x] Relier les documents juridiques depuis l'app.
- [x] Déployer les pages juridiques et vérifier publiquement l'accueil, l'appcast et le
  téléchargement. Le blocage Vercel du 29 septembre est résolu.
- [ ] Vérifier que le compte hébergeur possède les informations d'identification de l'éditeur.
- [ ] Publier `0.3.0` seulement après la recette complète.

## Dette non bloquante

- extraire progressivement `SettingsStore.swift` et `NotchController.swift` ;
- réduire les accès directs à `SettingsStore.shared` au profit de l'injection ;
- remplacer les `try?` liés à des opérations visibles par des erreurs récupérables ;
- ajouter des mesures de performance reproductibles ;
- compléter le SEO, le sitemap, les icônes et la version anglaise du site ;
- mettre à jour les captures marketing uniquement lorsqu'un changement visuel de l'app l'exige.

## Fonctionnalités futures, non requises pour finir `0.3.0`

- sélecteur ou liste blanche de sources média ;
- volume, AirPlay, favori ou spectre audio ;
- rappels datés et presets Timer personnalisables ;
- contenu riche du presse-papiers ;
- nouvelles familles de modules.

Ces idées doivent passer par une décision produit explicite. Elles ne constituent pas des bugs et
ne doivent pas retarder la recette de la candidate actuelle.
