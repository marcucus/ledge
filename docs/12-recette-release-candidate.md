# Recette release candidate

État au 27 septembre 2026 : la version publique est `0.1.0`. La prochaine candidate locale est
`0.2.0` (build `2`). Elle ne doit pas remplacer les assets du tag `v0.1.0` : Sparkle exige un numéro
de version et un build supérieurs pour proposer correctement la mise à jour.

## Vérifications automatisées

- [x] `swift build`
- [x] `swift test` — 41 tests dans 8 suites
- [x] `swiftlint lint --quiet Sources Tests` — aucune erreur
- [x] `make direct-appcast` — bundle ad hoc, DMG et signature EdDSA Sparkle
- [x] `codesign --verify --deep --strict dist/Ledge.app`
- [x] `hdiutil verify dist/Ledge-0.2.0.dmg`
- [x] validation XML de `dist/appcast.xml`
- [x] tests, ESLint et build de production de `ledge-site`
- [x] routes publiques Vercel : accueil `200`, dernière release `200`, appcast `200`, téléchargement
  `302` vers le DMG GitHub

## Recette manuelle sur le Mac de développement

1. Fermer toute instance existante de Ledge.
2. Ouvrir `dist/Ledge-0.2.0.dmg`, copier Ledge dans Applications, puis éjecter l'image.
3. Au premier lancement, utiliser clic droit → Ouvrir. La distribution ad hoc n'est volontairement
   pas notarisée : un double-clic direct peut être bloqué par Gatekeeper.
4. Vérifier les trois compositions, l'ouverture et la fermeture, le menu grille et le maintien
   ouvert pendant son utilisation.
5. Tester Média avec une vraie lecture Apple Music puis Spotify : pochette, lecture/pause,
   précédent/suivant, seek, aléatoire, répétition et ambient.
6. Tester un timer, une sortie de veille avec timer actif, la Drop Zone, le collage depuis
   l'historique, Calendrier, Notes et Raccourcis.
7. Accorder Accessibilité depuis Réglages Système, revenir dans une autre app et confirmer que le
   HUD Ledge remplace le HUD macOS sans relancer Ledge.
8. Avec VoiceOver, parcourir les onglets et les commandes média/timer, puis vérifier Réduire les
   animations.

## Recette indispensable sur un autre Mac

Cette partie ne peut pas être validée depuis la machine de développement.

1. Télécharger le DMG publié depuis le site, pas depuis le dossier `dist` local.
2. Vérifier le parcours Gatekeeper sur une machine qui n'a jamais lancé Ledge.
3. Confirmer le lancement sur macOS 14 ou plus récent et l'affichage sur écran interne/externe.
4. Installer d'abord la version publique précédente, puis publier la candidate et utiliser
   « Vérifier les mises à jour… » pour valider Sparkle de bout en bout.
5. Comparer l'empreinte SHA-256 téléchargée avec celle inscrite dans la release GitHub et affichée
   dans le changelog du site.

## Publication

La publication reste une action explicite et externe. Après validation manuelle, lancer :

```bash
make release CHANGELOG="Décrire ici les changements de la version 0.2.0"
```

Cette commande crée puis publie la GitHub Release et rend le DMG visible sur le site. Ne pas la
lancer tant que la recette manuelle locale et le texte du changelog ne sont pas validés.
