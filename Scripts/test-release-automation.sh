#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
resolver="$project_root/Scripts/resolve-version-bump.sh"
bumper="$project_root/Scripts/bump-version.sh"
workflow="$project_root/.github/workflows/release-version.yml"
publish_workflow="$project_root/.github/workflows/publish-release.yml"
appcast_generator="$project_root/Scripts/generate-appcast.sh"
publisher="$project_root/Scripts/publish-release.sh"
makefile="$project_root/Makefile"
fixture_dir=$(mktemp -d)

cleanup() {
  rm -rf "$fixture_dir"
}
trap cleanup EXIT

fail() {
  print -u2 "✗ $1"
  exit 1
}

[[ -x "$resolver" ]] || fail "resolve-version-bump.sh est absent ou non exécutable"
[[ -x "$bumper" ]] || fail "bump-version.sh est absent ou non exécutable"
[[ -f "$workflow" ]] || fail "release-version.yml est absent"
[[ -x "$appcast_generator" ]] || fail "generate-appcast.sh est absent ou non exécutable"
[[ -x "$publisher" ]] || fail "publish-release.sh est absent ou non exécutable"
[[ -f "$publish_workflow" ]] || fail "publish-release.yml est absent"

assert_equal() {
  local expected="$1"
  local actual="$2"
  local message="$3"
  [[ "$actual" == "$expected" ]] || fail "$message — attendu '$expected', obtenu '$actual'"
}

assert_bump() {
  local expected="$1"
  shift
  local actual
  actual=$($resolver "$@")
  assert_equal "$expected" "$actual" "résolution des labels $*"
}

make_plist() {
  local version="$1"
  local build="$2"
  local destination="$3"

  cp "$project_root/Sources/App/Info.plist" "$destination"
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$destination"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build" "$destination"
}

assert_version_bump() {
  local bump="$1"
  local current_version="$2"
  local current_build="$3"
  local expected_version="$4"
  local expected_build="$5"
  local plist="$fixture_dir/$bump.plist"

  make_plist "$current_version" "$current_build" "$plist"
  $bumper "$bump" "$plist" >/dev/null

  local actual_version
  local actual_build
  actual_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$plist")
  actual_build=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$plist")
  assert_equal "$expected_version" "$actual_version" "$bump met à jour la version"
  assert_equal "$expected_build" "$actual_build" "$bump incrémente le build"
}

assert_bump none
assert_bump patch version:patch
assert_bump minor documentation version:minor
assert_bump major version:major bug
assert_bump none version:none

if $resolver version:minor version:major >/dev/null 2>&1; then
  fail "des labels de version contradictoires doivent être refusés"
fi

if $resolver version:none version:patch >/dev/null 2>&1; then
  fail "version:none ne doit pas être combiné à un bump"
fi

assert_version_bump patch 0.3.0 3 0.3.1 4
assert_version_bump minor 0.3.9 12 0.4.0 13
assert_version_bump major 0.9.8 99 1.0.0 100

invalid_plist="$fixture_dir/invalid.plist"
make_plist "0.3" 3 "$invalid_plist"
if $bumper patch "$invalid_plist" >/dev/null 2>&1; then
  fail "une version non SemVer doit être refusée"
fi

grep -Fq 'if ! pr_url=$(gh pr create \' "$workflow" || \
  fail "la création de la PR de release doit propager les erreurs de gh"
grep -Fq 'Impossible de créer la PR de release' "$workflow" || \
  fail "l'échec de création de la PR doit rester explicite dans les logs"

grep -Fq 'workflows: [Release version]' "$publish_workflow" || \
  fail "la publication doit suivre le workflow de version"
grep -Fq 'workflow_dispatch:' "$publish_workflow" || \
  fail "la publication doit pouvoir être relancée manuellement"
grep -Fq 'secrets.SPARKLE_PRIVATE_KEY' "$publish_workflow" || \
  fail "la publication doit signer l'appcast avec un secret GitHub"
grep -Fq 'refs/tags/v$VERSION^{}' "$publisher" || \
  fail "la publication doit accepter un checkout détaché sur un tag distant"
grep -Fq 'sparkle_fw=$$(find .build/artifacts' "$makefile" || \
  fail "Sparkle.framework doit être recherché dans la recette après le build"
grep -Eq '^GENERATE_APPCAST[[:space:]]*=[^=]' "$makefile" || \
  fail "generate_appcast doit être résolu après le téléchargement des artefacts"

fake_generator="$fixture_dir/generate_appcast"
args_file="$fixture_dir/args"
stdin_file="$fixture_dir/stdin"
printf '%s\n' \
  '#!/bin/zsh' \
  'set -euo pipefail' \
  'print -r -- "$*" > "$CAPTURE_ARGS"' \
  'if [[ "$*" == *"--ed-key-file -"* ]]; then' \
  '  IFS= read -r key || true' \
  '  print -rn -- "$key" > "$CAPTURE_STDIN"' \
  'fi' > "$fake_generator"
chmod +x "$fake_generator"

CAPTURE_ARGS="$args_file" CAPTURE_STDIN="$stdin_file" \
  "$appcast_generator" "$fake_generator" "$fixture_dir"
assert_equal "--maximum-deltas 0 $fixture_dir" "$(<"$args_file")" \
  "la génération locale doit continuer d'utiliser le Trousseau"

CAPTURE_ARGS="$args_file" CAPTURE_STDIN="$stdin_file" SPARKLE_PRIVATE_KEY="test-private-key" \
  "$appcast_generator" "$fake_generator" "$fixture_dir"
assert_equal "--ed-key-file - --maximum-deltas 0 $fixture_dir" "$(<"$args_file")" \
  "la génération CI doit lire la clé privée sur stdin"
assert_equal "test-private-key" "$(<"$stdin_file")" \
  "la clé Sparkle CI doit être transmise sans modification"

print "✓ Automatisation de version : tests réussis"
