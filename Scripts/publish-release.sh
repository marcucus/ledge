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

delta_output=$(xmllint --xpath \
  "//*[local-name()='deltas']/*[local-name()='enclosure']/@url" \
  "$APPCAST_PATH" 2>/dev/null | sed -E 's/[[:space:]]*url="([^"]+)"/\1\n/g' || true)
delta_urls=(${(f)delta_output})
delta_paths=()
for delta_url in "${delta_urls[@]}"; do
  [[ -n "$delta_url" ]] || continue
  delta_name="${delta_url:t}"
  delta_path="${APPCAST_PATH:h}/$delta_name"
  [[ -f "$delta_path" ]] || {
    print -u2 "Delta référencé par l'appcast mais introuvable : $delta_path"
    exit 1
  }
  delta_paths+=("$delta_path")
done
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
auth_headers=(
  -H "Accept: application/vnd.github+json"
  -H "Authorization: Bearer $GITHUB_TOKEN"
  -H "X-GitHub-Api-Version: 2026-03-10"
)

lookup=$(curl --silent --show-error \
  "${auth_headers[@]}" \
  --write-out $'\n%{http_code}' \
  "$api_url/releases/tags/v$VERSION")
lookup_status=${lookup##*$'\n'}
lookup_body=${lookup%$'\n'*}

case "$lookup_status" in
  200)
    [[ "$(print -r -- "$lookup_body" | jq -r '.draft')" == "true" ]] || {
      print -u2 "La release v$VERSION existe déjà et n'est pas un brouillon"
      exit 1
    }
    existing_commit=$(print -r -- "$lookup_body" | jq -r '.target_commitish')
    [[ "$existing_commit" == "$commit" ]] || {
      print -u2 "Le brouillon v$VERSION vise $existing_commit au lieu de $commit"
      exit 1
    }
    release_response=$lookup_body
    print "▸ Reprise du brouillon GitHub v$VERSION…"
    ;;
  404)
    release_response=$(curl --fail --silent --show-error \
      -X POST \
      "${auth_headers[@]}" \
      -H "Content-Type: application/json" \
      --data-binary "$payload" \
      "$api_url/releases")
    ;;
  *)
    print -u2 "Impossible de rechercher la release v$VERSION (HTTP $lookup_status)"
    exit 1
    ;;
esac

upload_url=$(print -r -- "$release_response" | jq -r '.upload_url | split("{")[0]')
release_id=$(print -r -- "$release_response" | jq -r '.id')
[[ -n "$upload_url" && "$upload_url" != "null" ]] || {
  print -u2 "GitHub n'a pas retourné d'URL d'upload"
  exit 1
}

# Réapplique les métadonnées calculées localement lors d'une reprise de brouillon.
curl --fail --silent --show-error \
  -X PATCH \
  "${auth_headers[@]}" \
  -H "Content-Type: application/json" \
  --data-binary "$payload" \
  --output /dev/null \
  "$api_url/releases/$release_id"

dmg_name=$(basename "$DMG_PATH")

# Une relance après un upload partiel remplace uniquement les assets générés pour cette release.
asset_names=("$dmg_name" "appcast.xml")
for delta_path in "${delta_paths[@]}"; do
  asset_names+=("${delta_path:t}")
done
for asset_name in "${asset_names[@]}"; do
  for asset_id in $(print -r -- "$release_response" | jq -r \
    --arg name "$asset_name" '.assets[] | select(.name == $name) | .id'); do
    curl --fail --silent --show-error \
      -X DELETE \
      "${auth_headers[@]}" \
      --output /dev/null \
      "$api_url/releases/assets/$asset_id"
  done
done

curl --fail --silent --show-error \
  -X POST \
  "${auth_headers[@]}" \
  -H "Content-Type: application/x-apple-diskimage" \
  --data-binary "@$DMG_PATH" \
  --output /dev/null \
  "$upload_url?name=$dmg_name"

curl --fail --silent --show-error \
  -X POST \
  "${auth_headers[@]}" \
  -H "Content-Type: application/xml" \
  --data-binary "@$APPCAST_PATH" \
  --output /dev/null \
  "$upload_url?name=appcast.xml"

for delta_path in "${delta_paths[@]}"; do
  delta_name="${delta_path:t}"
  curl --fail --silent --show-error \
    -X POST \
    "${auth_headers[@]}" \
    -H "Content-Type: application/octet-stream" \
    --data-binary "@$delta_path" \
    --output /dev/null \
    "$upload_url?name=$delta_name"
done

curl --fail --silent --show-error \
  -X PATCH \
  "${auth_headers[@]}" \
  -H "Content-Type: application/json" \
  --data-binary '{"draft":false}' \
  --output /dev/null \
  "$api_url/releases/$release_id"
