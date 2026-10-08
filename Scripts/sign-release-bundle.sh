#!/bin/zsh
set -euo pipefail

bundle_path="${1:-}"
signing_identity="${2:-}"
script_dir="${0:A:h}"
sparkle_framework="$bundle_path/Contents/Frameworks/Sparkle.framework"
sparkle_version="$sparkle_framework/Versions/B"

[[ -d "$bundle_path" ]] || { print -u2 "Bundle introuvable : $bundle_path"; exit 1; }
[[ -n "$signing_identity" ]] || {
  print -u2 "Usage : $0 <Ledge.app> <identité Developer ID Application>"
  exit 1
}
[[ -d "$sparkle_version" ]] || {
  print -u2 "Sparkle.framework/Versions/B est absent du bundle"
  exit 1
}

required_components=(
  "$sparkle_version/XPCServices/Installer.xpc"
  "$sparkle_version/XPCServices/Downloader.xpc"
  "$sparkle_version/Autoupdate"
  "$sparkle_version/Updater.app"
)
for component in "${required_components[@]}"; do
  [[ -e "$component" ]] || { print -u2 "Composant Sparkle absent : $component"; exit 1; }
done

# Sparkle impose une signature de l'intérieur vers l'extérieur. Downloader.xpc conserve
# son entitlement réseau fourni par le framework ; les autres helpers n'héritent jamais
# des entitlements de Ledge.
codesign --force --options runtime --timestamp --sign "$signing_identity" \
  "$sparkle_version/XPCServices/Installer.xpc"
codesign --force --options runtime --timestamp --preserve-metadata=entitlements \
  --sign "$signing_identity" "$sparkle_version/XPCServices/Downloader.xpc"
codesign --force --options runtime --timestamp --sign "$signing_identity" \
  "$sparkle_version/Autoupdate"
codesign --force --options runtime --timestamp --sign "$signing_identity" \
  "$sparkle_version/Updater.app"
codesign --force --options runtime --timestamp --sign "$signing_identity" \
  "$sparkle_framework"

codesign --force --options runtime --timestamp \
  --entitlements "$script_dir/App.entitlements" \
  --sign "$signing_identity" "$bundle_path"

codesign --verify --deep --strict --verbose=2 "$bundle_path"
print "✓ Bundle Developer ID signé de l'intérieur vers l'extérieur"
