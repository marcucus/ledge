# Ledge 0.3.0

Cette version consolide Ledge autour de sept modules visibles et rend la candidate prête pour une
distribution directe avec mises à jour Sparkle.

## Nouveautés

- Trois compositions du panneau : Concentrée, Panoramique et Immersive, avec placement indépendant
  des modules dans la barre, la grille ou les éléments masqués.
- Persistance des minuteurs et du Pomodoro entre les relances, y compris après une veille ou une
  désactivation temporaire par profil d'application.
- Persistance chiffrée facultative de l'historique du presse-papiers, avec clé conservée dans le
  Trousseau macOS ; le mode par défaut reste entièrement en mémoire.
- Sélection fiable de l'écran cible et comportement adapté aux écrans externes sans encoche.
- Liens juridiques, réinitialisation complète des réglages et erreurs visibles pour le lancement à
  la connexion.

## Améliorations

- Commandes Média mieux associées au lecteur réellement affiché, avec identité de source et seek
  Apple Music via Automation lorsque nécessaire.
- Accessibilité renforcée pour Média, Timers et le HUD Système, avec prise en charge de Réduire les
  animations.
- Quick Look au clavier, partage et gestion plus robuste des fichiers supprimés dans Drop Zone.
- Copie Drop Zone hors du thread principal, avec progression et annulation entre les fichiers.
- Images du presse-papiers conservées en pleine définition et prévention de la ré-ingestion des
  contenus écrits par Ledge.
- Timeout, annulation réelle et retours d'erreur distincts pour les commandes Raccourcis.
- Conflits de raccourcis globaux et erreurs de permissions Calendrier/Notifications rendus visibles.
- Modules réellement arrêtés lorsqu'ils sont désactivés globalement ou par un profil d'application.
- Calendrier, Notes et Raccourcis mieux testés et plus explicites en cas d'autorisation refusée ou
  d'erreur système.

## Distribution

- macOS 14 ou version ultérieure sur Apple Silicon.
- DMG avec icône native, raccourci Applications et notice d'installation.
- Distribution directe non notarisée : après une première tentative d'ouverture, autoriser Ledge
  dans Réglages Système → Confidentialité et sécurité → « Ouvrir quand même ».
- Mises à jour complètes signées avec Sparkle EdDSA depuis la version 0.2.0.
