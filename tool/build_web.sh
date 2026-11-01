#!/usr/bin/env bash
# Builds the web app the way it is deployed: engine files (CanvasKit) served
# from our own Hosting instead of Google's CDN, then unused icon fonts removed
# so the first screen downloads as little as possible. Extra arguments go to
# flutter build web, for example:
#   tool/build_web.sh --dart-define=DATA_SOURCE=firestore --dart-define=APPS_SCRIPT_URL=<exec url>
set -euo pipefail
cd "$(dirname "$0")/.."
flutter build web --release --no-wasm-dry-run --no-web-resources-cdn "$@"
node tool/web/prune_fonts.mjs build/web
