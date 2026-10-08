#!/bin/zsh
set -euo pipefail

dmg_path="${1:-}"
[[ -f "$dmg_path" ]] || { print -u2 "DMG introuvable : $dmg_path"; exit 1; }

xcrun stapler validate "$dmg_path" >/dev/null 2>&1 || {
  print -u2 "Le DMG n'est pas notarisé ou son ticket Apple n'est pas agrafé."
  exit 1
}
codesign --verify --verbose=2 "$dmg_path"
spctl --assess --type open --context context:primary-signature --verbose=4 "$dmg_path"

print "✓ Signature, ticket Apple et évaluation Gatekeeper valides"
