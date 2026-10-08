#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
source_image="${1:-$project_root/Sources/App/Resources/ledgelogo.png}"
output_catalog="${2:-$project_root/Distribution/AppIcon.xcassets/AppIcon.appiconset}"
temporary_dir=$(mktemp -d /tmp/ledge-icon.XXXXXX)
master="$temporary_dir/icon_1024x1024.png"

cleanup() {
  rm -rf "$temporary_dir"
}
trap cleanup EXIT

mkdir -p "$output_catalog"
mkdir -p "$temporary_dir/module-cache"
SWIFT_MODULECACHE_PATH="$temporary_dir/module-cache" \
CLANG_MODULE_CACHE_PATH="$temporary_dir/module-cache" \
  xcrun swift "$project_root/Scripts/render-app-icon.swift" "$source_image" "$master"

for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$master" \
    --out "$output_catalog/icon_${size}x${size}.png" >/dev/null
  retina_size=$((size * 2))
  sips -z "$retina_size" "$retina_size" "$master" \
    --out "$output_catalog/icon_${size}x${size}@2x.png" >/dev/null
done

print "✓ Images d'icône générées : $output_catalog"
