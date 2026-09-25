#!/bin/zsh
set -euo pipefail

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  keychain_account="${GITHUB_TOKEN_ACCOUNT:-marcucus}"
  keychain_service="${GITHUB_TOKEN_SERVICE:-dev.ledge.github-release-token}"
  GITHUB_TOKEN=$(security find-generic-password \
    -a "$keychain_account" \
    -s "$keychain_service" \
    -w 2>/dev/null || true)
fi

: "${GITHUB_TOKEN:?GITHUB_TOKEN is required (environment or macOS Keychain service dev.ledge.github-release-token)}"
export GITHUB_TOKEN
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${VERSION:?VERSION is required}"
: "${BUILD_NUMBER:?BUILD_NUMBER is required}"
: "${MIN_OS:?MIN_OS is required}"
: "${DMG_PATH:?DMG_PATH is required}"
: "${APPCAST_PATH:?APPCAST_PATH is required}"
: "${CHANGELOG:?CHANGELOG is required}"

[[ -f "$DMG_PATH" ]] || { print -u2 "DMG introuvable : $DMG_PATH"; exit 1; }
[[ -f "$APPCAST_PATH" ]] || { print -u2 "Appcast introuvable : $APPCAST_PATH"; exit 1; }

file_size=$(stat -f%z "$DMG_PATH")
sha256=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')
sparkle_signature=$(xmllint --xpath \
  "string((//*[local-name()='enclosure']/@*[local-name()='edSignature'])[1])" \
  "$APPCAST_PATH")

[[ -n "$sparkle_signature" ]] || { print -u2 "Signature Sparkle absente de l'appcast"; exit 1; }

command -v jq >/dev/null || { print -u2 "jq est requis pour publier sur GitHub"; exit 1; }

[[ -z "$(git status --porcelain)" ]] || {
  print -u2 "Le dépôt doit être propre avant une publication"
  exit 1
}

branch=$(git branch --show-current)
commit=$(git rev-parse HEAD)
remote_commit=$(git ls-remote origin "refs/heads/$branch" | awk '{print $1}')
[[ -n "$remote_commit" && "$remote_commit" == "$commit" ]] || {
  print -u2 "Le commit local doit être poussé sur origin/$branch avant la publication"
  exit 1
}

metadata=$(jq -cn \
  --arg buildNumber "$BUILD_NUMBER" \
  --arg minOS "$MIN_OS" \
  --arg sha256 "$sha256" \
  --arg sparkleSignature "$sparkle_signature" \
  '{buildNumber:$buildNumber,minOS:$minOS,sha256:$sha256,sparkleSignature:$sparkleSignature}')

release_body=$(printf '%s\n\n<!-- ledge-release:%s -->' "$CHANGELOG" "$metadata")
prerelease=false
[[ "$VERSION" == *-* ]] && prerelease=true

payload=$(jq -cn \
  --arg tag "v$VERSION" \
  --arg name "Ledge $VERSION" \
  --arg body "$release_body" \
  --arg commit "$commit" \
  --argjson prerelease "$prerelease" \
  '{tag_name:$tag,target_commitish:$commit,name:$name,body:$body,draft:true,prerelease:$prerelease}')

api_url="https://api.github.com/repos/$GITHUB_REPOSITORY"
release_response=$(curl --fail --silent --show-error \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "X-GitHub-Api-Version: 2026-03-10" \
  -H "Content-Type: application/json" \
  --data-binary "$payload" \
  "$api_url/releases")

upload_url=$(print -r -- "$release_response" | jq -r '.upload_url | split("{")[0]')
release_id=$(print -r -- "$release_response" | jq -r '.id')
[[ -n "$upload_url" && "$upload_url" != "null" ]] || {
  print -u2 "GitHub n'a pas retourné d'URL d'upload"
  exit 1
}

dmg_name=$(basename "$DMG_PATH")

curl --fail --silent --show-error \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "X-GitHub-Api-Version: 2026-03-10" \
  -H "Content-Type: application/x-apple-diskimage" \
  --data-binary "@$DMG_PATH" \
  --output /dev/null \
  "$upload_url?name=$dmg_name"

curl --fail --silent --show-error \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "X-GitHub-Api-Version: 2026-03-10" \
  -H "Content-Type: application/xml" \
  --data-binary "@$APPCAST_PATH" \
  --output /dev/null \
  "$upload_url?name=appcast.xml"

curl --fail --silent --show-error \
  -X PATCH \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "X-GitHub-Api-Version: 2026-03-10" \
  -H "Content-Type: application/json" \
  --data-binary '{"draft":false}' \
  --output /dev/null \
  "$api_url/releases/$release_id"
