#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
resolver="$project_root/Scripts/resolve-version-bump.sh"
bumper="$project_root/Scripts/bump-version.sh"
workflow="$project_root/.github/workflows/release-version.yml"
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

print "✓ Automatisation de version : tests réussis"
