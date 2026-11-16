#!/usr/bin/env bash
# Serve the landing root as static files for Playwright.
cd "$(dirname "$0")/.." && exec python3 -m http.server "${PORT:-4173}" --bind 127.0.0.1
