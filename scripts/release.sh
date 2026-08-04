#!/bin/bash
# Tag, build and publish a GitHub release.
#
#   ./scripts/release.sh 1.0.0
#
# Stamps the version into Info.plist, builds a fresh Pomodoro.app, zips it with
# ditto (which preserves the bundle's signature) and attaches it to the tag as a
# release asset.
set -euo pipefail

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "usage: $(basename "$0") <version>   e.g. $(basename "$0") 1.0.0" >&2
    exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="v$VERSION"
ZIP="$ROOT/build/Pomodoro-$VERSION.zip"
# Unversioned copy so /releases/latest/download/Pomodoro.zip is a stable URL.
LATEST_ZIP="$ROOT/build/Pomodoro.zip"

cd "$ROOT"

if [ -n "$(git status --porcelain)" ]; then
    echo "working tree is dirty — commit first" >&2
    exit 1
fi

# Keep the bundle version in step with the tag.
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Resources/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" Resources/Info.plist
if [ -n "$(git status --porcelain Resources/Info.plist)" ]; then
    git commit -q -m "Set version to $VERSION" Resources/Info.plist
    git push -q origin HEAD
fi

./scripts/build-app.sh

mkdir -p "$ROOT/build"
rm -f "$ZIP"
# No --sequesterRsrc: it adds a __MACOSX folder to the unzipped output.
ditto -c -k --keepParent "$ROOT/Pomodoro.app" "$ZIP"
cp "$ZIP" "$LATEST_ZIP"

git tag -a "$TAG" -m "Pomodoro $VERSION"
git push -q origin "$TAG"

gh release create "$TAG" "$ZIP" "$LATEST_ZIP" \
    --title "Pomodoro $VERSION" \
    --notes-file - <<NOTES
Menu bar Pomodoro timer for macOS 14+ (Apple silicon).

### Install

\`\`\`sh
curl -L -o /tmp/Pomodoro.zip https://github.com/kossa/pomodoro/releases/latest/download/Pomodoro.zip
unzip -oq /tmp/Pomodoro.zip -d /Applications
xattr -dr com.apple.quarantine /Applications/Pomodoro.app
open /Applications/Pomodoro.app
\`\`\`

The app is ad-hoc signed, not notarized — hence the \`xattr\` step.
NOTES

echo "Published $TAG"
