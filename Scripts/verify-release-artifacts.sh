#!/bin/zsh
set -euo pipefail

: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${VERSION:?VERSION is required}"
: "${BUILD_NUMBER:?BUILD_NUMBER is required}"
: "${MIN_OS:?MIN_OS is required}"
: "${DMG_PATH:?DMG_PATH is required}"
: "${APPCAST_PATH:?APPCAST_PATH is required}"

bundle_path="${DMG_PATH:h}/Ledge.app"
[[ -d "$bundle_path" ]] || { print -u2 "Bundle introuvable : $bundle_path"; exit 1; }
[[ -f "$DMG_PATH" ]] || { print -u2 "DMG introuvable : $DMG_PATH"; exit 1; }
[[ -f "$APPCAST_PATH" ]] || { print -u2 "Appcast introuvable : $APPCAST_PATH"; exit 1; }

codesign --verify --deep --strict "$bundle_path"
hdiutil verify "$DMG_PATH" >/dev/null
xmllint --noout "$APPCAST_PATH"

item_xpath="(//*[local-name()='item'][*[local-name()='shortVersionString' and text()='$VERSION']])[1]"
appcast_build=$(xmllint --xpath "string($item_xpath/*[local-name()='version'])" "$APPCAST_PATH")
appcast_min_os=$(xmllint --xpath "string($item_xpath/*[local-name()='minimumSystemVersion'])" "$APPCAST_PATH")
appcast_url=$(xmllint --xpath "string($item_xpath/*[local-name()='enclosure']/@url)" "$APPCAST_PATH")
appcast_length=$(xmllint --xpath "string($item_xpath/*[local-name()='enclosure']/@length)" "$APPCAST_PATH")
appcast_signature=$(xmllint --xpath \
  "string($item_xpath/*[local-name()='enclosure']/@*[local-name()='edSignature'])" \
  "$APPCAST_PATH")

expected_url="https://github.com/$GITHUB_REPOSITORY/releases/latest/download/${DMG_PATH:t}"
expected_length=$(stat -f%z "$DMG_PATH")

[[ "$appcast_build" == "$BUILD_NUMBER" ]] || {
  print -u2 "Build appcast inattendu : $appcast_build (attendu : $BUILD_NUMBER)"
  exit 1
}
[[ "$appcast_min_os" == "$MIN_OS" ]] || {
  print -u2 "macOS minimum inattendu : $appcast_min_os (attendu : $MIN_OS)"
  exit 1
}
[[ "$appcast_url" == "$expected_url" ]] || {
  print -u2 "URL appcast inattendue : $appcast_url"
  exit 1
}
[[ "$appcast_length" == "$expected_length" ]] || {
  print -u2 "Taille appcast inattendue : $appcast_length (attendu : $expected_length)"
  exit 1
}
[[ -n "$appcast_signature" ]] || { print -u2 "Signature EdDSA absente"; exit 1; }

delta_output=$(xmllint --xpath \
  "$item_xpath/*[local-name()='deltas']/*[local-name()='enclosure']/@url" \
  "$APPCAST_PATH" 2>/dev/null | sed -E 's/[[:space:]]*url="([^"]+)"/\1\n/g' || true)
delta_urls=(${(f)delta_output})
for delta_url in "${delta_urls[@]}"; do
  [[ -n "$delta_url" ]] || continue
  delta_path="${APPCAST_PATH:h}/${delta_url:t}"
  [[ -f "$delta_path" ]] || {
    print -u2 "Delta référencé par l'appcast mais introuvable : $delta_path"
    exit 1
  }
done

sha256=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')
print "✓ Bundle, DMG et appcast v$VERSION (build $BUILD_NUMBER) valides"
print "  DMG : $expected_length octets"
print "  SHA-256 : $sha256"
print "  Deltas : ${#delta_urls[@]}"
