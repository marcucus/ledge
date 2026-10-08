#!/bin/zsh
set -euo pipefail

resolved=""

for label in "$@"; do
  case "$label" in
    version:patch)
      candidate="patch"
      ;;
    version:minor)
      candidate="minor"
      ;;
    version:major)
      candidate="major"
      ;;
    version:none)
      candidate="none"
      ;;
    *)
      continue
      ;;
  esac

  if [[ -n "$resolved" && "$resolved" != "$candidate" ]]; then
    print -u2 "Plusieurs labels de version sont présents. Garder un seul label version:* sur la PR."
    exit 1
  fi
  resolved="$candidate"
done

# Sans label explicite, aucune version ne doit être préparée.
print "${resolved:-none}"
