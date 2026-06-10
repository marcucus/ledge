# 03 — Module Presse-papiers & Drop Zone 📋

> Deux sous-fonctions complémentaires : **historique de copies** + **étagère de fichiers / partage**.
> Implémentation V2 (Drop Zone) puis V3 (Presse-papiers).

## Objectif

- **Presse-papiers** : ne plus jamais perdre une copie. Historique recherchable, recoller en 1 clic.
- **Drop Zone** : une étagère temporaire pour trimballer fichiers entre apps/fenêtres, et partager vite (AirDrop, etc.).

## Wireframes

### Drop Zone — glisser un fichier SUR l'encoche

```
   (on drague un fichier vers le haut de l'écran)
        ╭───────────────────────────────────────╮
       │            ⬇  Déposez ici               │   ← l'encoche s'ouvre
       │     ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐       │     en zone de dépôt
       │       Lâchez pour ajouter à l'étagère     │     dès qu'un drag est détecté
       │     └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘       │
        ╰───────────────────────────────────────╯
```

### État Ouvert — onglet Presse-papiers / Drop Zone

```
╭──────────────────────────────────────────────────────╮
│  🎵  📋  ⚙️  ⏱️                              ⚙   ✕    │
├──────────────────────────────────────────────────────┤
│  [ Presse-papiers ]   [ Étagère ]        🔍 Rechercher │
├──────────────────────────────────────────────────────┤
│  PRESSE-PAPIERS (récents)                              │
│  ┌──────────────────────────────────────────────────┐ │
│  │ 📝 "git rebase -i HEAD~3"           il y a 2 min  │ │
│  │ 🔗 https://exemple.com/article…     il y a 8 min  │ │
│  │ 🖼  capture-2026.png  (image)        il y a 12 min │ │
│  │ 📝 adrien227@gmail.com               il y a 1 h    │ │
│  └──────────────────────────────────────────────────┘ │
│  Clic = recoller · ⌘+clic = coller en texte brut       │
├──────────────────────────────────────────────────────┤
│  ÉTAGÈRE (fichiers en attente)                         │
│  ┌──────┐ ┌──────┐ ┌──────┐                            │
│  │ 📄   │ │ 🖼   │ │ 📦   │   ← glisser-déposer         │
│  │ doc  │ │ img  │ │ zip  │     vers/depuis ici         │
│  └──────┘ └──────┘ └──────┘                            │
│  [ AirDrop ]  [ Enregistrer… ]  [ Vider ]              │
╰──────────────────────────────────────────────────────╯
```

## Fonctionnalités

### Presse-papiers
| Fonction | Détail |
|---|---|
| Historique | N derniers éléments (texte, image, lien, fichier). N réglable. |
| Types | Texte riche/brut, images, URLs, couleurs (hex), chemins. |
| Recherche | Filtre instantané sur le contenu texte. |
| Recoller | Clic → remet dans le presse-papiers + colle dans l'app active. |
| Coller en brut | ⌘+clic → enlève la mise en forme. |
| Épingler | Garder un élément en haut (snippets fréquents). |
| Exclusions | Ne pas capturer depuis certaines apps (gestionnaires de mots de passe). |

### Drop Zone / Étagère
| Fonction | Détail |
|---|---|
| Capture par drag | Glisser un fichier vers l'encoche → s'ajoute à l'étagère. |
| Multi-fichiers | Accumuler plusieurs fichiers de sources différentes. |
| Sortie par drag | Glisser depuis l'étagère vers une app/fenêtre cible. |
| Partage | AirDrop, Mail, Messages, enregistrer dans un dossier. |
| Persistance | Étagère vidée au quit, ou conservée (réglable). |

## Source des données

- **Presse-papiers** : `NSPasteboard`. Pas d'API d'événement native → on surveille
  `changeCount` à **basse fréquence** (timer léger ~0,5–1 s) **uniquement** ; c'est la seule
  exception au « zéro polling », et elle est négligeable (lecture d'un entier).
- **Drag & drop** : `NSDraggingDestination` sur la fenêtre encoche, qui s'active visuellement
  dès qu'une session de drag globale est détectée.
- **AirDrop / partage** : `NSSharingService` / `NSSharingServicePicker`.

## Confidentialité (important)

Un historique de presse-papiers est **sensible**. Conception :
- Stockage **local uniquement**, jamais de réseau.
- **Liste d'exclusion** par défaut (apps marquées « concealed » / mots de passe → ignorées).
- Option : ne pas persister sur disque (RAM seulement).
- Option : chiffrer le cache sur disque.
- Effacement rapide (vider tout l'historique en 1 clic).

## Paramètres du module

- [ ] Activer Presse-papiers / Activer Drop Zone (séparément)
- [ ] Nombre d'éléments conservés (10 / 25 / 50 / illimité)
- [ ] Persister l'historique sur disque (oui / non) + chiffrement
- [ ] Apps exclues de la capture (liste)
- [ ] Étagère : vider au quit (oui / non)
- [ ] Capturer les images (oui / non — coût mémoire)

## Cas limites

- **Très grosse image copiée** → miniature + limite de taille de cache.
- **Fichier déplacé/supprimé** après ajout à l'étagère → marquer indisponible.
- **Drag de texte** (pas un fichier) vers l'encoche → l'ajouter comme note ?
