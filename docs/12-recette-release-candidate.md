# 12 — Recette release candidate

> Mise à jour le **5 octobre 2026** après la phase 3 locale.
>
> Version publique : `0.2.0` (build `2`). Candidate locale suivante : `0.3.0` (build `3`).
> La release `v0.2.0` et ses assets ne doivent jamais être remplacés : Sparkle exige une version
> et un build strictement supérieurs pour proposer correctement une mise à jour.

## État automatisé de la candidate

- [x] `swift build`
- [x] `swift test` — 116 tests dans 17 suites
- [x] `swiftlint lint --quiet Sources Tests` — aucune erreur ni avertissement
- [x] `make app` — bundle construit avec la licence Sparkle incluse
- [x] smoke test réel — le bundle optimisé démarre et reste actif pendant la mesure de 30 secondes
- [x] tests, ESLint et build de production de `ledge-site`
- [ ] CI GitHub verte sur le commit candidat — aucun push ne doit être effectué par l'agent
- [x] `make direct-appcast` — DMG et appcast `0.3.0` signés
- [x] `codesign --verify --deep --strict dist/Ledge.app`
- [x] `hdiutil verify dist/Ledge-0.3.0.dmg`
- [x] validation XML de `dist/appcast.xml`
- [x] pages juridiques publiques : mentions, confidentialité, conditions et licences en HTTP 200
- [x] routes publiques : accueil `200`, appcast `200`, téléchargement `302` vers le DMG GitHub

### Preuves de phase 3 — 5 octobre 2026

- DMG reconstruit depuis le code de phase 2 : **3 565 185 octets**.
- SHA-256 : `8b6078d6744a1c9b0c96648a8824ca4807ebb589f59a7eb69059603ef241e1d9`.
- Appcast local : version `0.3.0`, build `3`, macOS `14.0`, signature EdDSA présente, zéro delta.
- Gatekeeper rejette normalement l'app et le DMG actuels : ils sont signés ad hoc, sans ticket de
  notarisation (`source=no usable signature`).
- Cette machine possède un certificat Apple Development, mais aucun certificat Developer ID et
  aucune configuration `APPLE_ID`, `TEAM_ID` ou `APP_PASSWORD`. La notarisation est donc bloquée
  par des prérequis externes, pas par le code.
- Le site local passe désormais ESLint, 31 tests, le contrat visuel 0.3.0 et le build Next.js de
  production sans avertissement. La réduction de 33 à 31 correspond à la suppression des tests du
  code mort des anciennes timelines fusionnées ; les tests fonctionnels restants sont verts.
- Les routes publiques renvoient `200`, mais l'apex redirige vers `www.app-ledge.fr` et le champ
  `<link>` de l'appcast public pointait encore vers `ledge-notch.vercel.app`. Le code ignore
  désormais cette ancienne variable et force `https://app-ledge.fr`; le déploiement public reste
  à actualiser manuellement. L'ancienne variable Vercel peut être supprimée et l'apex doit encore
  être choisi comme domaine primaire côté hébergeur.
- Les traductions juridiques anglaises n'ont pas reçu de validation juridique humaine et gardent
  volontairement leur avertissement.

## Recette manuelle sur le Mac de développement

1. Fermer toute instance existante de Ledge.
2. Construire avec `make app`, ouvrir `dist/Ledge.app` et vérifier que la version affichée est
   `0.3.0` (build `3`).
3. Vérifier les trois compositions, l'ouverture et la fermeture, le menu grille et le maintien
   ouvert pendant son utilisation.
4. Vérifier le choix de l'écran cible, puis déconnecter et reconnecter l'écran externe.
5. Tester les trois politiques plein écran et un changement d'espace macOS.
6. Tester Média avec une vraie lecture Apple Music puis Spotify : pochette, lecture/pause,
   précédent/suivant, seek, aléatoire, répétition et ambient.
7. Ouvrir Apple Music et Spotify simultanément : la commande seek doit toujours agir sur le
   lecteur réellement affiché, sans clignotement ni retour à un état vide.
8. Tester un timer, quitter puis relancer Ledge, et effectuer une veille/réveil avec timer actif.
9. Tester Drop Zone, Quick Look au clavier, partage, collisions de noms et fichiers supprimés.
10. Tester le presse-papiers en RAM, la persistance chiffrée, les exclusions d'applications et le
    collage en texte brut. Un module désactivé ne doit plus capturer.
11. Tester Calendrier, Notes, Raccourcis et les profils par application.
12. Accorder Accessibilité, revenir dans une autre app et confirmer que le HUD Ledge remplace le
    HUD macOS sans relance.
13. Avec VoiceOver, parcourir navigation, progression Média, molettes Timer, Drop Zone et réglages.
14. Activer Réduire les animations et vérifier qu'aucune information ne disparaît.
15. Couper puis rétablir Lancement au démarrage et vérifier la gestion visible des erreurs.
16. Réinitialiser tous les réglages et confirmer le retour immédiat aux valeurs par défaut.
17. Ouvrir les quatre liens juridiques depuis À propos et depuis l'onboarding.

### Mesures CPU et mémoire reproductibles

Lancer le bundle, préparer le scénario dans l'app, puis mesurer chaque état pendant la même durée :

```bash
make measure-performance SCENARIO=idle DURATION=30 INTERVAL=1
make measure-performance SCENARIO=timer DURATION=30 INTERVAL=1
make measure-performance SCENARIO=media DURATION=30 INTERVAL=1
```

Chaque commande écrit un CSV horodaté dans `dist/` et affiche CPU moyen/max ainsi que RSS
moyenne/max. Conserver les trois CSV avec les notes de recette pour comparer les mêmes scénarios
entre candidates.

Mesure stabilisée au repos du 5 octobre 2026, après une première fenêtre incluant le démarrage :
**0,00 % CPU moyen**, **0,10 % max**, **91,1 Mo RSS moyen** et **91,2 Mo max** sur 30 mesures.
Les scénarios Timer et Média exigent encore une interaction réelle avec l'encoche et une lecture
Apple Music/Spotify ; ils ne sont pas cochés par une simple mesure du processus.

## Recette indispensable sur un autre Mac

Cette partie ne peut pas être validée depuis la machine de développement.

1. Installer d'abord la version publique `0.2.0` depuis son DMG GitHub.
2. Vérifier son parcours Gatekeeper sur une machine qui n'a jamais lancé Ledge.
3. Publier ensuite la candidate `0.3.0` et utiliser « Vérifier les mises à jour… » depuis `0.2.0`.
4. Confirmer téléchargement, validation Sparkle, remplacement, relance et conservation des réglages.
5. Confirmer le lancement sur macOS 14 ou plus récent et l'affichage sur écran interne/externe.
6. Télécharger ensuite le DMG depuis le site public et comparer son SHA-256 avec le changelog et
   les métadonnées de la GitHub Release.

## Publication

La publication reste une action explicite. Elle ne doit commencer qu'après validation de toutes les
cases ci-dessus et déploiement des pages juridiques du site.

```bash
make release CHANGELOG="Décrire ici les changements de la version 0.3.0"
```

Cette commande publie la GitHub Release, le DMG, l'appcast et chaque delta référencé par l'appcast.
Si un upload échoue, la même commande reprend uniquement le brouillon `v0.3.0` visant le même
commit et remplace ses assets partiels. Elle refuse de modifier une release déjà publique ou un
brouillon associé à un autre commit, ainsi que de publier un appcast qui référence un delta local
absent. Elle ne doit pas être lancée pour une simple vérification locale.
