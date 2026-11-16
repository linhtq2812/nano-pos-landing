#!/usr/bin/env bash
# Counter-app shots rendered by `flutter test` (no device, no build): copies
# tools/shots/pos_shots_test.dart into nano_pos_flutter/test/, runs it, always removes it,
# then converts the PNGs to WebP.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; root="$here/../.."
app="${NANO_POS_FLUTTER:-$root/../nano_pos_flutter}"
out="${SHOTS_RAW:-$(mktemp -d)}"; mkdir -p "$out"
flutter_root="$(dirname "$(dirname "$(readlink -f "$(command -v flutter)")")")"
icons="$flutter_root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf"
target="$app/test/landing_pos_shots_test.dart"
[ ! -e "$target" ] || { echo "refusing: $target already exists (left over from a killed run?)" >&2; exit 1; }
cp "$here/pos_shots_test.dart" "$target"
trap 'rm -f "$target"' EXIT
cd "$app"
flutter test test/landing_pos_shots_test.dart --concurrency=1 \
  --dart-define=SHOTS_OUT="$out" --dart-define=MATERIAL_ICONS="$icons"
for f in "$out"/pos-*.png; do
  python3 "$here/to_webp.py" "$f" "$root/assets/shots/$(basename "${f%.png}").webp" --width 720
done
echo "raw PNGs in $out"
