#!/bin/zsh
set -euo pipefail

scenario=${1:-idle}
duration=${2:-30}
interval=${3:-1}

[[ "$duration" == <-> && "$duration" -gt 0 ]] || {
  print -u2 "DURATION doit être un entier positif"
  exit 1
}
[[ "$interval" == <-> && "$interval" -gt 0 ]] || {
  print -u2 "INTERVAL doit être un entier positif"
  exit 1
}

pid=${LEDGE_PID:-$(pgrep -x Ledge | head -1)}
[[ -n "$pid" ]] || {
  print -u2 "Ledge n'est pas lancé. Construire avec make app puis ouvrir dist/Ledge.app."
  exit 1
}

mkdir -p dist
timestamp=$(date -u +%Y%m%dT%H%M%SZ)
output=${PERFORMANCE_OUTPUT:-dist/performance-${scenario}-${timestamp}.csv}
samples=$(( (duration + interval - 1) / interval ))

print "timestamp,scenario,pid,cpu_percent,rss_kb" > "$output"
for _ in {1..$samples}; do
  metrics=$(ps -p "$pid" -o %cpu=,rss= | awk '{$1=$1; print}')
  [[ -n "$metrics" ]] || {
    print -u2 "Le processus Ledge $pid s'est arrêté pendant la mesure"
    exit 1
  }
  cpu=${metrics%% *}
  rss=${metrics##* }
  print "$(date -u +%Y-%m-%dT%H:%M:%SZ),$scenario,$pid,$cpu,$rss" >> "$output"
  sleep "$interval"
done

awk -F, 'NR > 1 {cpu += $4; rss += $5; if ($4 > maxCPU) maxCPU=$4; if ($5 > maxRSS) maxRSS=$5; n++}
END {printf "✓ %d mesures — CPU moyen %.2f%%, max %.2f%% ; RSS moyen %.1f Mo, max %.1f Mo\n",
n, cpu/n, maxCPU, rss/n/1024, maxRSS/1024}' "$output"
print "  $output"
