#!/bin/zsh
set -euo pipefail

bundle_path="${1:-}"
output_path="${2:-}"
volume_name="${3:-Ledge}"
project_root="${0:A:h:h}"

[[ -d "$bundle_path" ]] || { print -u2 "Bundle introuvable : $bundle_path"; exit 1; }
[[ -n "$output_path" ]] || {
  print -u2 "Usage : $0 <Ledge.app> <Ledge-x.y.z.dmg> [nom du volume]"
  exit 1
}

staging_dir=$(mktemp -d /tmp/ledge-dmg-source.XXXXXX)
temporary_dmg="${output_path:h}/.${output_path:t}.temporary.dmg"

cleanup() {
  rm -rf "$staging_dir"
  rm -f "$temporary_dmg"
}
trap cleanup EXIT

ditto "$bundle_path" "$staging_dir/Ledge.app"
ln -s /Applications "$staging_dir/Applications"
cp "$project_root/Distribution/INSTALLATION.txt" "$staging_dir/Installation.txt"

rm -f "$output_path" "$temporary_dmg"
hdiutil create \
  -quiet \
  -volname "$volume_name" \
  -srcfolder "$staging_dir" \
  -ov \
  -format UDZO \
  "$temporary_dmg"
mv "$temporary_dmg" "$output_path"

print "✓ DMG créé : $output_path"
