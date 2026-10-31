#!/usr/bin/env bash
# Installs Flutter (stable) and the Firebase CLI. Runs once when the
# Codespace is created or rebuilt.
set -euo pipefail

FLUTTER_DIR="$HOME/flutter"

sudo apt-get update -y
sudo apt-get install -y --no-install-recommends curl git unzip xz-utils zip libglu1-mesa

# The Flutter tool's first build needs more memory than a busy Codespace has free.
bash "$(dirname "$0")/swap.sh"

if [ ! -d "$FLUTTER_DIR" ]; then
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
export PATH="$PATH:$FLUTTER_DIR/bin:$HOME/.pub-cache/bin"
grep -q 'flutter/bin' "$HOME/.bashrc" 2>/dev/null || \
  echo 'export PATH="$PATH:$HOME/flutter/bin:$HOME/.pub-cache/bin"' >> "$HOME/.bashrc"

flutter config --no-analytics --enable-web
flutter precache --web
flutter --version

npm install -g firebase-tools
firebase --version

flutter pub get
