#!/bin/zsh
set -euo pipefail

dmg_path="${1:-}"
[[ -f "$dmg_path" ]] || { print -u2 "DMG introuvable : $dmg_path"; exit 1; }

mount_dir=$(mktemp -d /tmp/ledge-dmg-check.XXXXXX)
is_mounted=false

cleanup() {
  if [[ "$is_mounted" == true ]]; then
    hdiutil detach "$mount_dir" >/dev/null 2>&1 || true
  fi
  rmdir "$mount_dir" 2>/dev/null || true
}
trap cleanup EXIT

hdiutil attach -nobrowse -readonly -mountpoint "$mount_dir" "$dmg_path" >/dev/null
is_mounted=true

[[ -d "$mount_dir/Ledge.app" ]] || { print -u2 "Ledge.app est absent du DMG"; exit 1; }
[[ -L "$mount_dir/Applications" ]] || {
  print -u2 "Le raccourci Applications est absent du DMG"
  exit 1
}
[[ "$(readlink "$mount_dir/Applications")" == "/Applications" ]] || {
  print -u2 "Le raccourci Applications ne pointe pas vers /Applications"
  exit 1
}
[[ -f "$mount_dir/Installation.txt" ]] || {
  print -u2 "La notice d'installation est absente du DMG"
  exit 1
}

"${0:A:h}/verify-app-bundle.sh" "$mount_dir/Ledge.app"
print "✓ DMG installable : Ledge.app → Applications"
