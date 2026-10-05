# Audit produit v1 — Ledge

Date de l’audit : 5 octobre 2026

> **Mise à jour du 5 octobre 2026 :** le chantier site des phases 1 à 3 est terminé localement :
> sécurité HTTP, origine canonique `app-ledge.fr`, fallback de release, captures 0.3.0, page
> Support FR/EN, licences générées, galerie des modules, story raccourcie et découpage de
> `ScrollStoryStage`. ESLint, 31 tests, contrat visuel et build Next.js sont verts. Les constats
> site non cochés plus bas sont conservés comme photographie de l'audit initial. Aucun push n'a
> été effectué.

## Verdict

Ledge a une base technique saine et une identité produit déjà forte, mais le produit n’est pas
encore prêt pour une **v1 grand public**.

| Axe | État estimé |
| --- | ---: |
| Fondations techniques macOS | 8/10 |
| Qualité fonctionnelle | 8/10 |
| UX et accessibilité | 8/10 |
| Site dans le dépôt | 7,5/10 |
| Distribution grand public | 3/10 |
| Production réellement accessible | 2/10 |
| Préparation globale v1 | 6,5/10 |

La version actuelle peut devenir une bonne bêta publique rapidement. Pour une vraie v1 crédible,
il faut d’abord sécuriser la distribution, corriger quelques problèmes fonctionnels sensibles et
effectuer une vraie recette sur plusieurs Mac.

## Avancement du plan

### Phase 2 — Fiabilité v1 terminée localement le 5 octobre 2026

- Drop Zone : copie hors du `MainActor`, progression par fichier et annulation.
- Presse-papiers : images conservées en pleine définition, prévention de la ré-ingestion des
  écritures de Ledge et description honnête de la limite des exclusions d'apps.
- Raccourcis : timeout de 5 s pour la liste et 30 s pour l'exécution, annulation qui termine le
  processus, et erreurs distinctes.
- Permissions : erreurs système visibles et séparées d'un refus pour Calendrier et Notifications.
- Accessibilité : les animations Ambient continues sont arrêtées avec « Réduire les animations ».
- Raccourcis globaux : les échecs Carbon et conflits sont affichés dans les réglages.
- Validation locale : `swift build`, **116 tests dans 17 suites** et SwiftLint sans avertissement.

La politique du propriétaire reste : **aucun push par l'agent**. Les validations distantes et
toute publication restent donc des actions manuelles d'Adrien.

### Phase 3 — Release candidate : automatisation locale terminée, recette humaine bloquante

- Bundle, DMG et appcast 0.3.0 reconstruits et vérifiés depuis le code de phase 2.
- Site local entièrement vert et routes publiques disponibles.
- Repos stabilisé mesuré à 0,00 % CPU moyen et 91,1 Mo RSS moyen sur 30 secondes.
- Gatekeeper confirme que le paquet ad hoc n'est pas une distribution grand public notarisée.
- Aucun certificat Developer ID ni identifiant NotaryTool n'est disponible sur cette machine.
- Restent obligatoires : recette interactive Média/Timer/VoiceOver/écrans/veille, second Mac,
  mise à jour Sparkle 0.2.0 → 0.3.0 et validation juridique anglaise.

## Blocages P0 avant tout lancement

### 1. Finaliser le domaine acquis

Adrien a acquis `app-ledge.fr` le 5 octobre 2026. Il devient l’unique domaine canonique du produit.
Le domaine `ledge.app` appartient à un tiers qui le propose sur GoDaddy pour **15 000 USD**, en
location-achat pour **1 250 USD par mois**, ou sur offre ; il ne fait pas partie du projet et ne
doit plus apparaître comme origine officielle.

Le DNS, le rattachement Vercel, HTTPS et les routes publiques fonctionnent. Avant publication, il
reste à :

- faire de `app-ledge.fr` le domaine primaire au lieu de rediriger l'apex vers `www` ;
- remplacer l'ancienne origine `ledge-notch.vercel.app` encore injectée dans l'appcast public ;
- valider les pages FR/EN et les métadonnées SEO après ce changement ;
- créer les adresses de contact nécessaires, par exemple `support@app-ledge.fr`.

Le code et la documentation utilisent désormais `https://app-ledge.fr` comme origine canonique.
Le flux Sparkle par défaut de l’application pointe directement vers GitHub et reste distinct.

### 2. Choisir une vraie stratégie de distribution

Pour une v1 grand public, la cible recommandée est :

- signature Developer ID ;
- notarisation Apple ;
- DMG signé ;
- validation Gatekeeper sur une machine propre.

Le parcours actuel « Ouvrir quand même » convient à une bêta pour utilisateurs techniques, mais
il dégrade fortement la confiance et la conversion d’un lancement Internet.

### 3. Valider les dépôts distants et leurs CI côté propriétaire

- Les CI distantes n’ont pas validé les branches de release.
- Adrien a demandé qu'aucun push ne soit effectué par l'agent ; la publication distante est donc
  volontairement hors du périmètre d'exécution automatisée.

### 4. Faire une recette réelle du bundle

La matrice minimale devrait couvrir :

- installation propre et mise à jour depuis 0.2.0 ;
- toutes les versions de macOS officiellement supportées ;
- au moins deux Mac, dont un MacBook avec encoche ;
- écran externe et multi-écrans ;
- veille/réveil, plein écran et changement de session ;
- Apple Music et Spotify en lecture réelle ;
- permissions Accessibilité, Automation, Calendrier et Notifications accordées, refusées puis
  retirées ;
- VoiceOver, navigation clavier et réduction des animations.

### 5. ✅ Drop Zone corrigée en phase 2

Les entrées/sorties sont désormais exécutées hors du thread principal. La vue affiche la
progression et permet l'annulation entre deux fichiers.

### 6. ✅ Fidélité du presse-papiers corrigée en phase 2

L'image complète est conservée et recollée sans la réduction destructive historique à 128 px.
La consommation mémoire des gros historiques d'images devra être mesurée pendant la recette.

### 7. ✅ Confidentialité clarifiée en phase 2

L’exclusion d’une application repose parfois sur l’application au premier plan lors du prochain
polling. Si l’utilisateur change rapidement d’application après une copie, une donnée sensible
peut être attribuée au mauvais processus.

Les profils qui désactivent complètement le module restent la protection stricte recommandée. La
limite est désormais expliquée dans l'interface, sans promesse d'exclusion absolue, et Ledge ne
réimporte plus ses propres écritures au prochain sondage.

### 8. Faire relire les textes juridiques anglais

Les pages anglaises affichent elles-mêmes qu’elles doivent être relues juridiquement avant
publication. Cette mention ne doit pas rester sur une v1 publique.

## P1 — À finir pour une v1 solide

### Application

- Ajouter un sélecteur d’applications aux profils au lieu de demander un identifiant de bundle
  technique.
- Clarifier la réinitialisation : elle remet les réglages à zéro mais ne supprime pas toutes les
  données de modules, la langue, le lancement à la connexion ou les favoris Shortcuts.
- Remplacer l’écriture de Notes dans `UserDefaults` à chaque frappe par une sauvegarde fichier
  atomique et temporisée.
- Tester et documenter précisément le comportement de la luminosité, qui dépend de
  `DisplayServices`, une API privée.
- Mesurer et réduire les quelque 100 Mo de mémoire au repos rapportés par la documentation.
  L’ancien objectif de 10–20 Mo n’est pas réaliste dans l’état actuel.

### Site

- Remplacer les captures codées sous `product-story/0.2.0` par une version générée depuis une
  source unique. Le générateur 0.3.0 écrit encore un manifeste 0.2.0.
- Corriger l’avertissement du build Next.js dans `src/lib/social-image.tsx` : l’accès fichier
  dynamique peut embarquer tout le projet dans le bundle serveur.
- Ajouter CSP, `Referrer-Policy`, `X-Content-Type-Options` et une `Permissions-Policy`.
- Distinguer « aucune release » d’une panne GitHub. Aujourd’hui, le site masque parfois une
  indisponibilité comme si aucune version n’existait.
- Prévoir un dernier manifeste de release connu afin que le téléchargement ne disparaisse pas
  lors d’une panne temporaire de l’API GitHub.
- Réduire la dépendance au récit scrollé de quinze écrans. Le repli mobile et mouvement réduit est
  bon, mais le parcours desktop reste long et très dirigiste.
- Ajouter une page Support avec signalement de bug, demande de fonctionnalité et informations
  nécessaires au diagnostic.
- Remplacer l’adresse personnelle exposée partout par une adresse dédiée, par exemple
  `support@app-ledge.fr`.
- Automatiser la génération de la page des licences depuis les dépendances pour éviter les
  versions manuelles obsolètes.

## Refactorisations recommandées

### 1. Supprimer le code mort et les réglages hérités

- `ExpandedView` et l’ancien `PeekView` ne sont plus utilisés.
- `notchDetectionMode` est persisté mais sans effet.
- `targetScreenIdentifier` et `targetScreenName` ne servent plus qu’à la migration.

### 2. Clarifier la propriété du cycle de vie des modules

Les différentes fenêtres multi-écrans partagent les mêmes instances de modules, alors que chaque
`NotchController` suit son propre état de démarrage. Le coordinateur devrait posséder les sources
et leur cycle de vie ; les contrôleurs devraient seulement présenter leur état.

### 3. Isoler les accès non sûrs

Media, System et les raccourcis globaux utilisent plusieurs états `nonisolated(unsafe)` et
singletons statiques. Regrouper ces accès derrière des acteurs ou des exécuteurs série rendrait les
intégrations système plus robustes.

### 4. Centraliser les métadonnées produit

Version, build, macOS minimal, URL canonique, dépôt GitHub, version des captures et liens
juridiques sont dupliqués entre Swift, Makefile, scripts et TypeScript.

### 5. Centraliser l’URL canonique dans l’application

Les liens juridiques de l’application pointent désormais vers `app-ledge.fr`, mais l’origine reste
une constante propre au code Swift. Elle devrait à terme provenir d’une configuration de build
partagée ou générée afin d’éviter une nouvelle divergence avec le site.

### 6. Découper `ScrollStoryStage.tsx`

Ses quelque 590 lignes cumulent animation, navigation, accessibilité, gestion du hash, scroll
interne, rendu SVG et affichage statique. C’est désormais un composant central trop risqué à
modifier.

## Documentation à remettre en cohérence

- `docs/12`, `docs/13` et `docs/14` sont désormais alignés sur les 116 tests actuels.
- Certaines pages décrivent encore un réglage manuel de détection de l’encoche qui n’existe pas
  dans l’interface.
- La documentation promet parfois un changement de langue immédiat alors que l’application
  demande un redémarrage.
- Plusieurs textes parlent de String Catalog alors que les ressources effectives sont des fichiers
  `.strings`.
- Le README décrit encore le module Système comme un véritable onglet avec jauges et contrôles,
  alors qu’il est volontairement transverse et masqué.
- Les décisions historiques sur l’écran unique contredisent le support multi-écrans actuel.
- `docs/PROMPT_IA.md` devrait être archivé hors de la documentation active.
- `.impeccable/design.json` et `DESIGN.md` ont divergé ; il faudrait régénérer la documentation
  visuelle avant de reprendre un chantier d’interface.

## Idées produit — après stabilisation de la v1

Il est préférable de ne pas ajouter de huitième gros module avant le lancement. Les meilleures
idées sont celles qui renforcent les fonctions existantes :

- **Centre de diagnostic local** : permissions, version, écran détecté, modules actifs, état
  Sparkle et export d’un rapport sans données personnelles.
- **Profils par application faciles** : choisir une app ouverte et proposer automatiquement de
  couper le presse-papiers pour les gestionnaires de mots de passe.
- **Drop Zone avancée** : progression, destinations récentes et action
  « déplacer/copier/partager ».
- **Sessions Focus** : lancer un minuteur, masquer certains modules et activer automatiquement un
  profil.
- **Palette d’actions rapide** : rechercher un module, un raccourci ou une action depuis le
  clavier.
- **Canaux Stable/Bêta** : les utilisateurs volontaires peuvent tester les intégrations macOS
  fragiles sans exposer toute la base.
- **Sauvegarde/export des réglages** : utile pour les profils et l’organisation des modules.
- **Onboarding interactif** : faire réellement démarrer un minuteur, déposer un fichier et lire un
  média plutôt que seulement présenter les fonctions.
- **Diagnostics et métriques opt-in** : au minimum compter anonymement les échecs de permission,
  de mise à jour et les crashs, avec consentement explicite.

## Feuille de route recommandée

### Étape 1 — Canal de lancement, 2 à 3 jours

Configuration DNS/Vercel de `app-ledge.fr`, droits Git, CI distante, liens canoniques, publication
0.3.0, vérification du téléchargement, de l’appcast et de la mise à jour.

### Étape 2 — Fiabilité v1 — ✅ terminée localement le 5 octobre 2026

Drop Zone asynchrone, presse-papiers fidèle et mieux protégé, timeout Shortcuts, erreurs de
permissions, animations accessibles et conflits de raccourcis.

### Étape 3 — Release candidate, environ 1 semaine

Notarisation, recette multi-Mac, VoiceOver, performances, veille/réveil, Apple Music/Spotify, mise
à jour depuis 0.2.0 et revue juridique anglaise.

### Étape 4 — Lancement

Publier d’abord une **0.9 bêta publique**, puis la **1.0** après une courte période de retour
terrain. Les sept modules peuvent rester, mais la communication devrait se concentrer sur trois
usages forts : Média, Presse-papiers/Drop Zone et Timers.

## Vérifications effectuées pendant l’audit

- Lecture de l’ensemble de la documentation active et historique des deux dépôts.
- Inspection des sources de production, configurations, scripts et tests des deux dépôts.
- `swift build` : vert.
- `swift test` : 116 tests dans 17 suites, tous verts.
- SwiftLint sur `Sources` et `Tests` : vert.
- `make verify-release` : bundle, DMG et appcast 0.3.0 build 3 valides.
- Site : lint vert, 33 tests verts, contrat visuel vert et build de production réussi.
- `npm audit --omit=dev --audit-level=high` : aucune vulnérabilité de niveau élevé.
- Contrôle de la fiche de vente GoDaddy de `ledge.app` à 15 000 USD, vérification de la
  disponibilité puis de l’acquisition de `app-ledge.fr`, du déploiement Vercel et de la release
  GitHub publique.
