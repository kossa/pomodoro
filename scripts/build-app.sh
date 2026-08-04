#!/bin/bash
# Build Pomodoro.app.
#
# We compile with swiftc directly rather than `swift build`: the SwiftPM manifest
# library shipped with the Command Line Tools is version-mismatched and cannot
# compile Package.swift. Package.swift is kept for use with a full Xcode install.
#
# A real .app bundle is required for LSUIElement (no Dock icon) and for
# UserNotifications to be available.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/Pomodoro.app"
MIN_MACOS="14.0"
ARCH="$(uname -m)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O \
    -target "${ARCH}-apple-macosx${MIN_MACOS}" \
    -parse-as-library \
    "$ROOT"/Sources/Pomodoro/*.swift \
    -o "$APP/Contents/MacOS/Pomodoro"

cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

# Regenerate the icon if it is missing (it is checked in, so normally it isn't).
[ -f "$ROOT/Resources/AppIcon.icns" ] || swift "$ROOT/scripts/make-icon.swift"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# Strip extended attributes before signing: if any survive into the release zip,
# `unzip` materializes them as ._* files and the signature seal breaks.
xattr -cr "$APP"

# Ad-hoc signature: enough for this Mac, not for distribution.
codesign --force --sign - "$APP"

echo "Built $APP"
echo "Run it with:  open \"$APP\""
