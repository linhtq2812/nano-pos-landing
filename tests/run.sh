#!/usr/bin/env bash
# Run the landing tests with nano-pos-web's Playwright install (no package.json here).
# node_modules is a git-ignored symlink so `import '@playwright/test'` resolves.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
web="${NANO_POS_WEB:-$root/../nano-pos-web}"
[ -e "$root/node_modules" ] || ln -s "$web/node_modules" "$root/node_modules"
cd "$root"
exec node "$web/node_modules/@playwright/test/cli.js" test -c tests/playwright.config.ts "$@"
