#!/usr/bin/env bash
# Capture Nano Admin screenshots against LOCAL Supabase, then convert to WebP.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; root="$here/../.."
web="${NANO_POS_WEB:-$root/../nano-pos-web}"
db="${NANO_POS_DB:-$root/../nano-pos-db}"
LOCAL_ANON_KEY="$(cd "$db" && supabase status -o json | python3 -c 'import json,sys;print(json.load(sys.stdin)["ANON_KEY"])')" \
  || { echo "supabase status failed: start local Supabase in $db first" >&2; exit 1; }
export LOCAL_ANON_KEY
export NANO_POS_WEB="$web" SHOTS_RAW="${SHOTS_RAW:-$(mktemp -d)}"
[ -e "$root/node_modules" ] || ln -s "$web/node_modules" "$root/node_modules"
cd "$here"
node "$web/node_modules/@playwright/test/cli.js" test -c playwright.config.ts
for f in "$SHOTS_RAW"/*.png; do
  python3 "$here/to_webp.py" "$f" "$root/assets/shots/$(basename "${f%.png}").webp" --width 1440
done
echo "raw PNGs in $SHOTS_RAW"
