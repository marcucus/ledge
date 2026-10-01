# 10 — Audit historique & suivi

> Audit initial établi le **24 juin 2026**, conservé pour expliquer les décisions prises.
> Il ne constitue plus la liste des travaux restants.
>
> Légende gravité : 🔴 bloquant / important · 🟡 à traiter · 🟢 mineur / cosmétique.

## État courant au 30 septembre 2026

- Les jalons historiques 0 à 3 et les jalons de finalisation 1 à 4 sont terminés.
- L'application compte huit modules compilés, sept onglets visibles et 110 tests dans 17 suites.
- La version publique est `0.2.0`. La candidate locale est `0.3.0` (build `3`).
- Le plan actif est désormais le **jalon 5** de [l'audit de finalisation](13-audit-finalisation.md) :
  CI, recette manuelle, second Mac, mise à jour Sparkle et publication.
- Les routes juridiques et de distribution de `ledge-site` sont maintenant déployées et répondent
  correctement. La CI de l'app reste à valider après commit sur GitHub.
- Les constats ci-dessous décrivent l'état au moment de l'audit initial. Le tableau **Suivi** indique
  leur résolution ; le code et les docs 09, 12 et 13 priment en cas de contradiction.

---

## A. Verdict qualité

Le code est **nettement au-dessus de la moyenne** et applique réellement la [doc 08](08-conventions-de-code.md) :

- **0** `fatalError`, **0** `try!`, **0** force-unwrap `!`, **0** `print`/`NSLog` traînant.
- Architecture modulaire propre : `Core` + 5 modules cloisonnés (aucune dépendance croisée),
  API privées derrière protocole ([MediaSource](../Sources/Modules/Media/MediaSource.swift)).
- Concurrence correcte (`@MainActor`, `@Observable`, continuations), dégradation propre partout.
- Vie privée presse-papiers : skip du `org.nspasteboard.ConcealedType` (gestionnaires de mots de
  passe), historique **en RAM uniquement**.

**Bémol global** : ~7000 lignes pour **67 lignes de tests** (uniquement `NotchGeometry`). Le prompt
fondateur exige « tout passe les tests » — c'est le point le plus en décalage avec la constitution.

---

## B. Features manquantes (specs prévues, non livrées)

| # | Manque | Source | Gravité |
|---|--------|--------|---------|
| B1 | **Raccourcis non personnalisables** : [GlobalShortcutManager](../Sources/App/GlobalShortcutManager.swift) câble en dur ⌥Espace/⌥V/⌥T/⌥M. La page Réglages laisse croire le contraire → UI trompeuse. | doc 06 | 🔴 |
| B2 | **Agrégation des notifications système** (onglet Notifs du module Timer). | doc 05 | 🟡 (pas d'API publique — à arbitrer) |
| B3 | **Persistance du presse-papiers** entre sessions (perdu au quit ; aucune option d'opt-in). | doc 03 | 🟡 |
| B4 | **Pochette Apple Music fiable** (toujours partielle via AppleScript). | doc 09 | 🟡 |
| B5 | **Détail batterie complet** : cycles / santé / temps restant promis par le wireframe. À confirmer. | doc 04 | 🟢 |
| B6 | **Distribution** : résolu côté code — clé Sparkle réelle, feed injecté au build et publication gratuite via GitHub Releases, sans compte Apple. | doc 09 | ✅ |

> Déjà présent (plus avancé que la doc 09 ne le dit) : AirDrop (`NSSharingServicePicker`), lanceur
> d'apps, notifications `UserNotifications`, launch-at-login (`SMAppService`), sélecteur de langue.

---

## C. Audit sécurité

| # | Constat | Détail | Gravité |
|---|---------|--------|---------|
| S1 | **Usage descriptions absentes de l'Info.plist** | Le code lance `osascript` (Automation/Apple Events) mais il **manque `NSAppleEventsUsageDescription`**. Sous Hardened Runtime + notarisation, la permission peut être refusée silencieusement → seek/pochette cassés sans message. | 🔴 |
| S2 | **Sparkle** | Résolu : clé EdDSA réelle dans le bundle et feed injecté par `make release`. | ✅ |
| S3 | `disable-library-validation = true` | Nécessaire pour `dlopen` MediaRemote/DisplayServices, donc justifié, mais affaiblit la validation. À documenter pour la notarisation. | 🟡 |
| S4 | **CGEventTap clavier global** (`.cghidEventTap`) | Surface puissante. Implémentation saine (ne logge/ne stocke rien, filtre sur codes média) — à ne jamais étendre sans revue. | 🟡 |
| S5 | Presse-papiers — filtrage partiel | Skip `ConcealedType` ✓, mais contenus sensibles non marqués restent en historique RAM. À mentionner dans la doc confidentialité. | 🟢 |
| S6 | Cosmétique légal | Copyright `© 2024` dans [Info.plist](../Sources/App/Info.plist) vs `© 2026` ailleurs. | 🟢 |

**Positifs** : AppleScript statique avec `Int(position)` → pas d'injection ; pochette Spotify en
HTTPS (`i.scdn.co`) ; absence de sandbox cohérente avec les frameworks privés.

---

## D. Audit performance

Principe actuel : **presque rien au repos**. Les anciens pollings permanents du HUD et du média
ont été supprimés ; le presse-papiers conserve la seule lecture périodique permanente, légère et
justifiée par l'absence d'événement système public équivalent.

| # | Constat | Impact | Reco |
|---|---------|--------|------|
| P1 | [SystemObserver](../Sources/Modules/System/SystemObserver.swift) : volume CoreAudio événementiel ; luminosité sans polling dans le mode par défaut. | ✅ Résolu. Le suivi à 0,2 s n'existe que si l'utilisateur désactive « clavier uniquement ». La permission Accessibilité est revue au changement d'app. | Conserver ce comportement. |
| P2 | Resynchronisation Apple Music via ScriptingBridge, sans création répétée de processus. | ✅ Résolu. | Valider avec une lecture réelle. |
| P3 | Poll de secours média limité à trois tentatives au lancement ; suivi 1 s/5 s uniquement pendant une lecture active. | ✅ Résolu au repos. | Conserver l'arrêt immédiat hors lecture. |
| P4 | [ClipboardSource](../Sources/Modules/Clipboard/ClipboardSource.swift) poll 0,8 s (lecture d'un `Int`). | Négligeable, justifié. | OK. |
| P5 | Monitor global `.leftMouseDragged` permanent (détection drag fichier). | Callback à chaque drag. | Acceptable ; éventuellement n'armer qu'au besoin. |

**Déjà optimisé** : `dominantColor` recalculée seulement au changement de pochette ; `visibleModules`
paresseux ; animations factorisées.

---

## E. Améliorations (dette / robustesse, sans nouvelle feature)

1. **Tests** : couvrir [NotchController](../Sources/Core/NotchWindow/NotchController.swift)
   (priorités ambient, transitions HUD↔ambient↔expanded), décodage touches média, merge `MediaState`.
2. **Code mort** : `SettingsStore.launchAtLogin` est écrit mais jamais lu (le toggle réel utilise
   `SMAppService.mainApp.status`). À supprimer.
3. **Aligner README/doc** : nuancer « zéro polling » (P1–P3) ; passer le statut README
   (« Conception ») et la doc 09 à « implémentation avancée ».
4. **Centraliser les littéraux** de geometry dupliqués (`notchW: 190 / notchH: 32` dans
   [NotchWindow](../Sources/Core/NotchWindow/NotchWindow.swift) et
   [NotchController](../Sources/Core/NotchWindow/NotchController.swift)).
5. **Convertir PROMPT_IA.md** en `CLAUDE.md` (le bloc « premier message attendu » est obsolète).

---

## F. Nouvelles fonctionnalités (idées)

**Quick wins (fort effet, faible coût)**
- **Calendrier / prochain événement** dans l'ambient (EventKit) : « Réunion dans 12 min ».
- **Épingler un item du presse-papiers** (favoris hors trim) + recherche dans l'historique.
- **Glisser-déposer *depuis* la Drop Zone** vers une autre app (sortie, pas que l'entrée).
- **Aperçu QuickLook** d'un fichier de la Drop Zone au survol.
- **Mute micro / caméra en appel** comme toggle + indicateur de confidentialité.

**Différenciants (signature produit)**
- **Indicateur d'enregistrement écran/micro** façon « Now Recording ».
- **Progression de tâches longues** (Time Machine, AirDrop, copie Finder) dans l'anneau.
- **AirDrop entrant** affiché dans l'encoche (réception animée).
- **Mode Focus** : apparence/modules synchronisés avec le Focus macOS actif.
- **Profils par app active** : modules différents selon l'app au premier plan.

**Modules entièrement nouveaux**
- **Batterie d'accessoires** (AirPods, souris, clavier — `IOBluetooth`) / Météo.
- **Module Raccourcis (Shortcuts.app)** : lancer un raccourci depuis l'encoche.
- **Notes éphémères / codes 2FA** sous l'encoche.

**Plateforme / écosystème**
- **SDK de plugin** documenté (`NotchModule` est déjà un bon contrat).
- **Sync iCloud** des réglages (KVS).
- **Thèmes** et formes d'encoche alternatives.

---

## Clôture de l'audit

Les jalons issus de cet audit ont été traités ou explicitement écartés. Leur historique détaillé
est conservé dans les commits et dans [l'audit de finalisation](13-audit-finalisation.md).

Ce document n'est plus un plan d'action. Le backlog opérationnel unique de la candidate 0.3.0 est
[la liste de finalisation](14-taches-finalisation.md), tandis que [l'état courant](09-avancement-et-contexte.md)
décrit le produit effectivement livré.
