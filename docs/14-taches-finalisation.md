# 14 — Tâches de finalisation de Ledge

> Audit du **30 septembre 2026**, établi après lecture des documents et vérification du code.
>
> Objectif : terminer et publier la candidate **0.3.0**. Les idées produit futures ne doivent pas
> retarder cette version.

## État vérifié

- `swift build` : réussi.
- `swift test` : **99 tests dans 14 suites**, tous réussis.
- `swiftlint lint --quiet Sources Tests` : aucune erreur ni avertissement.
- `SettingsStore.swift` (328 lignes) et `NotchController.swift` (367 lignes) sont sous le seuil de
  400 lignes.
- La candidate est découpée sur `codex/release-0.3.0` en sept commits cohérents. Le push reste
  bloqué : le jeton HTTPS courant n'a pas le scope `workflow` requis pour modifier la CI et aucune
  clé SSH autorisée n'est disponible sur cette machine.

## P0 — Corriger avant la recette de release

> ✅ Terminé le **30 septembre 2026** : les quatre défauts sont corrigés et couverts par les tests.

### 1. Garantir le chiffrement de la migration du presse-papiers

Dans `ClipboardHistoryStore.load()`, un ancien historique en clair est décodé puis réenregistré
avec `try?`. Si l'écriture chiffrée échoue, le chargement réussit quand même et le fichier en clair
reste sur disque.

- [x] Remplacer l'échec silencieux par une erreur remontée à `ClipboardModule`.
- [x] Garantir un remplacement atomique du fichier en clair par sa version chiffrée.
- [x] Ajouter un test simulant un répertoire non inscriptible ou un échec d'écriture.
- [x] Vérifier que l'interface affiche alors l'erreur récupérable de persistance.

**Fichier principal :** `Sources/Modules/Clipboard/ClipboardHistoryStore.swift`.

### 2. Ne pas perdre les timers lors d'un changement de profil d'app

`NotchController` appelle `TimerModule.stop()` lorsqu'un profil de l'application active désactive
le module. `stop()` annule actuellement les sources, vide les entrées et supprime leur persistance.
Un simple changement d'application peut donc détruire un minuteur.

- [x] Faire de `stop()` un arrêt d'activité non destructif.
- [x] Conserver l'état persistant pendant une désactivation temporaire.
- [x] Resynchroniser les échéances lors de la réactivation.
- [x] Prévoir une action explicite séparée si la désactivation globale doit réellement supprimer
  les minuteurs.
- [x] Ajouter un test : timer actif → profil qui masque Timers → retour au profil normal.

**Fichiers principaux :** `TimerModule.swift`, `NotchController+ModuleLifecycle.swift` et
`NotchControllerTests.swift`.

### 3. Respecter la désactivation de Drop Zone

Le monitor global de drag reste actif indépendamment de l'activation du module. Il peut encore
ouvrir le panneau et produire une contribution ambient lorsque Drop Zone est désactivée.

- [x] Ignorer l'approche d'un fichier lorsque le module Drop Zone n'est pas activé par les règles
  globales ou le profil courant.
- [x] Retirer la contribution ambient et l'état de drag dans `DropZoneModule.stop()`.
- [x] Vérifier qu'un module désactivé ne provoque ni ouverture, ni sélection, ni ambient.
- [x] Ajouter des tests pour la désactivation globale et par profil d'app.

**Fichiers principaux :** `NotchWindow.swift`, `NotchController.swift`, `DropZoneModule.swift`.

### 4. Nettoyer le cycle de vie des observations

`ClipboardModule.observeSettings()` se réarme après chaque changement sans vérifier que le module
est toujours démarré. Des cycles `start()` / `stop()` peuvent laisser plusieurs chaînes
d'observation actives.

- [x] Ajouter un état `isStarted` ou un numéro de génération invalidé dans `stop()`.
- [x] Empêcher tout réarmement après l'arrêt du module.
- [x] Vérifier les tâches asynchrones de Média et Raccourcis selon le même contrat.
- [x] Ajouter un test `start → stop → start → changement de réglage` sans double traitement.

## P1 — Stabiliser la candidate

### 5. Ajouter les tests encore manquants

- [x] Tests dédiés de `CalendarModule` : autorisation, refus, démarrage et arrêt du polling.
- [x] Tests de `NotesModule` : chargement, sauvegarde et effacement avec `UserDefaults` isolé.
- [x] Tests de `ShortcutsModule` avec une abstraction injectable du processus `/usr/bin/shortcuts`.
- [x] Tests de l'assemblage App : modules enregistrés, Système absent des onglets et présent comme
  source transverse.
- [x] Tests des nouveaux défauts de cycle de vie décrits en P0.

### 6. Finaliser et publier la CI de l'application

- [x] Découper les changements actuels en commits cohérents sans mélanger les sujets.
- [x] Ajouter et commiter `.github/workflows/ci.yml`.
- [ ] Pousser la branche candidate et obtenir une exécution distante verte.
- [x] Ajouter un smoke test `make app` dans la CI macOS.
- [x] Vérifier dans ce smoke test le `Info.plist`, les localisations, la licence Sparkle et
  `codesign --verify --deep --strict`.

### 7. Valider le paquet de distribution

- [x] Exécuter `make direct-appcast` pour la version `0.3.0` build `3`.
- [x] Exécuter `codesign --verify --deep --strict dist/Ledge.app`.
- [x] Exécuter `hdiutil verify dist/Ledge-0.3.0.dmg`.
- [x] Valider `dist/appcast.xml` avec `xmllint`.
- [x] Vérifier que l'appcast contient la bonne version, le build, la signature EdDSA, la taille et
  l'URL du DMG attendu.
- [x] Comparer le SHA-256 calculé avec les métadonnées qui seront publiées.

Le bundle, le DMG et l'appcast ont été régénérés et vérifiés le **1er octobre 2026**. Le
DMG pèse **3 434 842 octets** et son SHA-256 est
`1dffa27718e326555d0e2a5176fe9618229045b949b29d2b2aaf93dcf4a60ab6`. L'appcast contient la
version `0.3.0`, le build `3`, macOS `14.0` et une signature EdDSA. La génération désactive les
deltas pour cette release et recrée l'appcast afin de ne conserver aucune ancienne référence. Le
script de publication sait néanmoins téléverser chaque delta référencé et refuse un delta local
manquant si cette option est réactivée.

### 8. Effectuer la recette sur le Mac de développement

- [ ] Tester les trois compositions, la grille, l'ouverture et toutes les fermetures.
- [ ] Tester Apple Music et Spotify seuls puis simultanément.
- [ ] Valider pochette, lecture, seek, répétition, aléatoire et permission Automation.
- [ ] Tester les trois politiques plein écran et les changements d'espace.
- [ ] Tester l'écran interne, un écran externe, la déconnexion et la reconnexion.
- [ ] Tester un timer pendant une veille/réveil et après relance de Ledge.
- [ ] Tester Drop Zone, Quick Look, partage, collisions de noms et fichiers supprimés.
- [ ] Tester le presse-papiers en RAM, la persistance chiffrée, les exclusions et le collage brut.
- [ ] Tester Calendrier, Notes, Raccourcis et les profils par application.
- [ ] Vérifier Accessibilité et le remplacement du HUD macOS.
- [ ] Effectuer une passe VoiceOver et Réduire les animations.
- [ ] Tester le lancement à la connexion et la réinitialisation des réglages.
- [ ] Ouvrir tous les liens juridiques depuis l'app.
- [ ] Mesurer CPU et RAM au repos, pendant un timer et pendant une lecture média.

Mesure locale partielle au repos après lancement de `dist/Ledge.app` : **0,0 % CPU** et environ
**100 Mo RSS**. Les mesures pendant un timer et une lecture média restent à effectuer avec les
scénarios fonctionnels ci-dessus.

### 9. Effectuer la recette indispensable sur un second Mac

- [ ] Installer la version publique `0.2.0` sur une machine vierge.
- [ ] Valider le parcours Gatekeeper.
- [ ] Tester ensuite la mise à jour Sparkle `0.2.0` → `0.3.0`.
- [ ] Vérifier la conservation des réglages et la relance.
- [ ] Vérifier macOS 14+ et les écrans interne/externe.
- [ ] Télécharger le DMG depuis le site et comparer son SHA-256.

### 10. Publier `0.3.0`

- [ ] Vérifier d'abord que les tâches bloquantes de `../ledge-site/docs/TACHES-FINALISATION.md`
  sont terminées.
- [x] Préparer un changelog utilisateur précis (`docs/RELEASE-NOTES-0.3.0.md`).
- [ ] Exécuter explicitement `make release CHANGELOG="…"`.
- [ ] Vérifier la GitHub Release, ses assets et ses métadonnées.
- [ ] Vérifier immédiatement le téléchargement public, l'appcast et la mise à jour Sparkle.

## P2 — Dette non bloquante

- [x] Extraire progressivement `SettingsStore.swift` et `NotchController.swift` sous 400 lignes.
- [x] Réduire les accès à `SettingsStore.shared` au profit de l'injection.
- [x] Remplacer les `try?` de persistance des timers par une erreur visible et récupérable.
- [x] Supprimer ou isoler les vues et réglages Système devenus inaccessibles depuis la décision de
  conserver ce module hors navigation.
- [x] Rendre `publish-release.sh` récupérable après un échec d'upload : reprendre ou supprimer
  proprement la release brouillon au lieu de laisser un tag bloquant.
- [x] Ajouter des mesures de performance reproductibles.
- [x] Consolider les docs 01 à 06 : distinguer clairement vision historique, fonctions livrées et
  fonctions volontairement hors périmètre.
- [x] Réduire `docs/10-audit-et-plan.md` à son rôle d'archive et garder ce document comme backlog
  opérationnel de la candidate.

## Hors périmètre de `0.3.0`

Ces idées exigent une nouvelle décision produit et ne doivent pas retarder la release :

- AirPlay, volume par source, favori et spectre audio ;
- contenu riche du presse-papiers ;
- rappels datés et nouveaux presets Timer ;
- météo, Focus, AirDrop entrant, codes 2FA et progression des tâches système ;
- chargement dynamique de plugins tiers ;
- nouvelles familles de modules.

## Définition de « terminé »

La version `0.3.0` est terminée lorsque :

1. les quatre défauts P0 sont corrigés et couverts par des tests ;
2. les deux CI distantes sont vertes sur les commits candidats ;
3. le bundle, le DMG et l'appcast sont validés ;
4. les recettes du Mac de développement, du site et du second Mac sont terminées ;
5. la release est publiée sans remplacer les assets de `0.2.0` ;
6. le site sert la nouvelle version et Sparkle propose correctement la mise à jour.
