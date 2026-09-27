# Product

<!-- impeccable:product-schema 1 -->

## Platform

macOS

## Users

Ledge s'adresse à toute personne utilisant un Mac compatible, quel que soit son niveau technique
ou sa situation quotidienne. L'interface doit rester immédiatement compréhensible pour un nouvel
utilisateur tout en demeurant rapide et discrète pour un utilisateur régulier.

## Product Purpose

Ledge transforme l'encoche du Mac en un point d'accès vivant à des informations et actions utiles :
média, minuteurs, fichiers, presse-papiers, raccourcis, calendrier et notes. Le produit réussit
lorsqu'il donne accès à ces fonctions en un geste, puis disparaît sans interrompre le travail.

## Positioning

Ledge n'est pas une fenêtre flottante supplémentaire : son interface prolonge visuellement et
spatialement l'encoche matérielle du Mac. Elle peut reproduire ce point d'ancrage sur un écran sans
encoche grâce à une pseudo-encoche cohérente.

## Operating Context

L'app vit dans la barre de menus, sans icône permanente dans le Dock. Elle reste invisible au repos,
apparaît au survol ou lors d'un événement utile, puis s'ouvre en panneau modulaire sous l'encoche.
Une fenêtre macOS séparée permet de régler les modules, l'apparence, l'écran cible, les permissions,
les profils par application et les raccourcis.

## Capabilities and Constraints

- Application native SwiftUI et AppKit, distribuée directement pour macOS 14 ou version ultérieure.
- Cinq états d'interface : `collapsed`, `ambient`, `peeking`, `hud` et `expanded`.
- Sept modules visibles dans la navigation ; le module Système alimente le statut et le HUD.
- Les réglages et profils par application personnalisent l'ordre et l'activation des modules.
- Les écrans externes utilisent une pseudo-encoche et la cible choisie persiste entre les connexions.
- Tous les textes visibles existent en français et en anglais.
- Les permissions sont demandées de façon contextuelle et toute fonction doit échouer proprement.
- Le produit doit rester léger au repos et respecter « Réduire les animations » ainsi que VoiceOver.

## Brand Commitments

Le nom est Ledge. Le produit doit sembler être une extension naturelle du matériel Apple : précis,
calme, immédiat et jamais envahissant. L'encoche et son mouvement d'expansion sont les actifs de
marque les plus reconnaissables. Le nouvel onboarding éditorial sert de premier niveau de qualité,
mais ne constitue pas encore un système graphique complet.

## Evidence on Hand

- Vision et interaction : `docs/01-concept-et-interaction.md`.
- Architecture des réglages : `docs/06-ecran-parametres.md`.
- État produit vérifié : `docs/09-avancement-et-contexte.md` et `docs/10-audit-et-plan.md`.
- Logo existant : `Sources/App/Resources/ledgelogo.png`.
- Onboarding existant : `Sources/App/Onboarding/`.
- Aucun témoignage, chiffre d'usage, prix ou validation commerciale ne doit être inventé.

## Product Principles

1. Compréhensible sans mode d'emploi.
2. Invisible quand il n'est pas sollicité.
3. Une information principale claire par état et par module.
4. Personnalisable sans rendre les réglages intimidants.
5. Natif, accessible et cohérent avec les comportements du Mac.

## Accessibility & Inclusion

L'interface doit fonctionner au clavier, exposer des libellés VoiceOver utiles, conserver un contraste
suffisant et respecter le réglage macOS « Réduire les animations ». La compréhension ne doit jamais
dépendre uniquement d'une couleur, d'une icône ou d'une animation.
