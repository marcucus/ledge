#!/bin/zsh
set -euo pipefail

bump="${1:-}"
plist="${2:-Sources/App/Info.plist}"

case "$bump" in
  patch|minor|major)
    ;;
  *)
    print -u2 "Usage : $0 <patch|minor|major> [Info.plist]"
    exit 1
    ;;
esac

[[ -f "$plist" ]] || {
  print -u2 "Info.plist introuvable : $plist"
  exit 1
}

version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$plist")
build=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$plist")

if [[ ! "$version" =~ '^([0-9]+)\.([0-9]+)\.([0-9]+)$' ]]; then
  print -u2 "Version invalide : '$version' (format attendu : MAJOR.MINOR.PATCH)"
  exit 1
fi

major="$match[1]"
minor="$match[2]"
patch="$match[3]"

if [[ ! "$build" =~ '^[0-9]+$' ]]; then
  print -u2 "Numéro de build invalide : '$build' (entier attendu)"
  exit 1
fi

case "$bump" in
  patch)
    (( patch += 1 ))
    ;;
  minor)
    (( minor += 1 ))
    patch=0
    ;;
  major)
    (( major += 1 ))
    minor=0
    patch=0
    ;;
esac

next_version="$major.$minor.$patch"
next_build=$((build + 1))

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $next_version" "$plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $next_build" "$plist"

print "version=$next_version"
print "build=$next_build"
