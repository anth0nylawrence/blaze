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

DMG_VERSIONED="$DIST/${APP_NAME}-macOS-${VER}-universal.dmg"
DMG_LATEST="$DIST/${APP_NAME}-latest-macOS-universal.dmg"

# --- Signing config ---
SIGNING_IDENTITY="${BLAZE_SIGNING_IDENTITY:-}"
NOTARIZE_PROFILE="${BLAZE_NOTARIZE_PROFILE:-}"

sign_enabled() {
  [[ -n "$SIGNING_IDENTITY" ]]
}

notarize_enabled() {
  [[ -n "$NOTARIZE_PROFILE" ]]
}

# --- Stage DMG contents ---
rm -rf "$STAGE"
mkdir -p "$STAGE"

echo "==> Staging app for DMG..."
cp -R "$APP_PATH" "$STAGE/$APP_NAME.app"

echo "==> Adding Applications shortcut..."
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG_VERSIONED" "$DMG_LATEST"

# --- Create DMG ---
echo "==> Creating DMG: $DMG_VERSIONED"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$DMG_VERSIONED" >/dev/null

# --- Sign DMG ---
if sign_enabled; then
  echo "==> Signing DMG..."
  codesign --force --timestamp \
    --sign "$SIGNING_IDENTITY" \
    "$DMG_VERSIONED"

  codesign --verify --verbose=2 "$DMG_VERSIONED"
  echo "    DMG signature valid"
else
  echo "==> Skipping DMG signing (BLAZE_SIGNING_IDENTITY not set)"
fi

# --- Notarize DMG ---
if sign_enabled && notarize_enabled; then
  echo "==> Notarizing DMG..."
  echo "    Submitting to Apple (this may take a few minutes)..."

  xcrun notarytool submit "$DMG_VERSIONED" \
    --keychain-profile "$NOTARIZE_PROFILE" \
    --wait

  echo "==> Stapling ticket to DMG..."
  xcrun stapler staple "$DMG_VERSIONED"
  xcrun stapler validate "$DMG_VERSIONED"
  echo "    DMG notarization complete"
else
  if sign_enabled; then
    echo "==> Skipping DMG notarization (BLAZE_NOTARIZE_PROFILE not set)"
  fi
fi

# --- Create latest copy ---
echo "==> Copying to stable 'latest' name: $DMG_LATEST"
cp -f "$DMG_VERSIONED" "$DMG_LATEST"

# --- Cleanup ---
rm -rf "$STAGE"

echo "==> Done."
ls -lh "$DMG_VERSIONED" "$DMG_LATEST"
