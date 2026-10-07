#!/bin/zsh
set -euo pipefail

bundle_path="${1:-dist/Ledge.app}"
info_plist="$bundle_path/Contents/Info.plist"
resources="$bundle_path/Contents/Resources"

[[ -d "$bundle_path" ]] || { print -u2 "Bundle introuvable : $bundle_path"; exit 1; }
[[ -f "$info_plist" ]] || { print -u2 "Info.plist introuvable : $info_plist"; exit 1; }
[[ -x "$bundle_path/Contents/MacOS/Ledge" ]] || {
  print -u2 "Exécutable Ledge absent du bundle"
  exit 1
}

icon_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconName" "$info_plist" 2>/dev/null || true)
[[ -n "$icon_name" ]] || { print -u2 "CFBundleIconName est absent"; exit 1; }
[[ -f "$resources/Assets.car" ]] || {
  print -u2 "Catalogue d'icônes absent : $resources/Assets.car"
  exit 1
}
[[ -f "$resources/$icon_name.icns" ]] || {
  print -u2 "Icône Finder absente : $resources/$icon_name.icns"
  exit 1
}

codesign --verify --deep --strict "$bundle_path"
print "✓ Bundle valide avec icône : $icon_name"
