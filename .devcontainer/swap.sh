#!/usr/bin/env bash
# Adds a 4 GB swap file if none is active. Without it, Flutter builds get
# killed when the Codespace is low on memory.
set -euo pipefail
if [ -z "$(swapon --show --noheadings 2>/dev/null)" ]; then
  sudo fallocate -l 4G /tmp/swapfile
  sudo chmod 600 /tmp/swapfile
  sudo mkswap /tmp/swapfile >/dev/null
  sudo swapon /tmp/swapfile || echo "Could not enable swap; continuing without it."
fi
