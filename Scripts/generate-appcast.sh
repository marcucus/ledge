#!/bin/zsh
set -euo pipefail

generator="${1:?Chemin de generate_appcast requis}"
archives="${2:?Répertoire des archives requis}"

[[ -x "$generator" ]] || {
  print -u2 "generate_appcast introuvable ou non exécutable : $generator"
  exit 1
}
[[ -d "$archives" ]] || {
  print -u2 "Répertoire des archives introuvable : $archives"
  exit 1
}

if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  print -rn -- "$SPARKLE_PRIVATE_KEY" | \
    "$generator" --ed-key-file - --maximum-deltas 0 "$archives"
else
  "$generator" --maximum-deltas 0 "$archives"
fi
