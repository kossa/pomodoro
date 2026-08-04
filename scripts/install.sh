#!/bin/bash
# Build (if needed) and install Pomodoro.app into /Applications.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/Pomodoro.app"

[ -d "$APP" ] || "$ROOT/scripts/build-app.sh"

osascript -e 'quit app "Pomodoro"' 2>/dev/null || true
rm -rf "/Applications/Pomodoro.app"
cp -R "$APP" /Applications/

echo "Installed /Applications/Pomodoro.app"
open "/Applications/Pomodoro.app"
