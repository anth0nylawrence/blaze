#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-}"
VERSION="${2:-}"

if [[ -z "$APP_PATH" || -z "$VERSION" ]]; then
  echo "Usage: $0 /path/to/Blaze.app v0.1.0"
  exit 1
fi

VER="${VERSION#v}"
APP_NAME="Blaze"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$REPO_ROOT/dist"
STAGE="$DIST/dmg-stage"

DMG_VERSIONED="$DIST/${APP_NAME}-macOS-${VER}-arm64.dmg"
DMG_LATEST="$DIST/${APP_NAME}-latest-macOS-arm64.dmg"

rm -rf "$STAGE"
mkdir -p "$STAGE"

echo "==> Staging app for DMG..."
cp -R "$APP_PATH" "$STAGE/$APP_NAME.app"

echo "==> Adding Applications shortcut..."
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG_VERSIONED" "$DMG_LATEST"

echo "==> Creating DMG (versioned): $DMG_VERSIONED"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$DMG_VERSIONED" >/dev/null

echo "==> Copying DMG to stable 'latest' name: $DMG_LATEST"
cp -f "$DMG_VERSIONED" "$DMG_LATEST"

echo "==> Done."
ls -lh "$DMG_VERSIONED" "$DMG_LATEST"
