#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 v0.1.0"
  exit 1
fi
VER="${VERSION#v}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG_DIR="$REPO_ROOT/Blaze"
APP_NAME="Blaze"
BUNDLE_ID="dev.getblaze.Blaze"
MIN_MACOS="14.0"
ICON_ICNS="$PKG_DIR/Resources/AppIcon.icns"
ENTITLEMENTS="$PKG_DIR/Resources/Blaze.entitlements"

# --- Signing config (optional - graceful skip if not set) ---
SIGNING_IDENTITY="${BLAZE_SIGNING_IDENTITY:-}"
NOTARIZE_PROFILE="${BLAZE_NOTARIZE_PROFILE:-}"

sign_enabled() {
  [[ -n "$SIGNING_IDENTITY" ]]
}

notarize_enabled() {
  [[ -n "$NOTARIZE_PROFILE" ]]
}

# --- Build ---
cd "$PKG_DIR"

echo "==> Building release with SwiftPM..."
swift build -c release --arch arm64 --arch x86_64

BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
EXE="$BIN_DIR/$APP_NAME"

if [[ ! -x "$EXE" ]]; then
  echo "ERROR: Expected executable not found: $EXE"
  echo "Contents of bin dir:"
  ls -la "$BIN_DIR"
  exit 1
fi

DIST="$REPO_ROOT/dist"
APP="$DIST/$APP_NAME.app"

echo "==> Creating app bundle: $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$EXE" "$APP/Contents/MacOS/$APP_NAME"

if [[ -f "$ICON_ICNS" ]]; then
  echo "==> Copying app icon"
  cp "$ICON_ICNS" "$APP/Contents/Resources/AppIcon.icns"
else
  echo "WARNING: Icon not found at $ICON_ICNS (app will use default icon)"
fi

# Copy SwiftPM resource bundles (common: *.bundle like GRDB_GRDB.bundle)
shopt -s nullglob
for b in "$BIN_DIR"/*.bundle; do
  echo "==> Copying bundle: $(basename "$b")"
  cp -R "$b" "$APP/Contents/Resources/"
done

# Copy any dylibs if present (some packages build local dylibs)
for d in "$BIN_DIR"/*.dylib; do
  echo "==> Copying dylib: $(basename "$d")"
  cp "$d" "$APP/Contents/MacOS/"
done
shopt -u nullglob

# Create Info.plist
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleExecutable</key><string>${APP_NAME}</string>
  <key>CFBundleShortVersionString</key><string>${VER}</string>
  <key>CFBundleVersion</key><string>${VER}</string>
  <key>LSMinimumSystemVersion</key><string>${MIN_MACOS}</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>CFBundleIconFile</key><string>AppIcon.icns</string>
</dict>
</plist>
PLIST

# --- Code Signing ---
if sign_enabled; then
  echo "==> Signing app bundle with: $SIGNING_IDENTITY"

  # Sign nested items first (inside out)
  # Sign any dylibs in MacOS/
  for item in "$APP/Contents/MacOS/"*.dylib; do
    [[ -f "$item" ]] || continue
    echo "    Signing: $(basename "$item")"
    codesign --force --timestamp --options runtime \
      --sign "$SIGNING_IDENTITY" \
      "$item"
  done

  # Sign resource bundles
  for item in "$APP/Contents/Resources/"*.bundle; do
    [[ -d "$item" ]] || continue
    echo "    Signing: $(basename "$item")"
    codesign --force --timestamp --options runtime \
      --sign "$SIGNING_IDENTITY" \
      "$item"
  done

  # Sign the main executable
  echo "    Signing main executable"
  if [[ -f "$ENTITLEMENTS" ]]; then
    codesign --force --timestamp --options runtime \
      --entitlements "$ENTITLEMENTS" \
      --sign "$SIGNING_IDENTITY" \
      "$APP/Contents/MacOS/$APP_NAME"
  else
    codesign --force --timestamp --options runtime \
      --sign "$SIGNING_IDENTITY" \
      "$APP/Contents/MacOS/$APP_NAME"
  fi

  # Sign the app bundle itself
  echo "    Signing app bundle"
  if [[ -f "$ENTITLEMENTS" ]]; then
    codesign --force --timestamp --options runtime \
      --entitlements "$ENTITLEMENTS" \
      --sign "$SIGNING_IDENTITY" \
      "$APP"
  else
    codesign --force --timestamp --options runtime \
      --sign "$SIGNING_IDENTITY" \
      "$APP"
  fi

  # Verify signature
  echo "==> Verifying signature..."
  codesign --verify --deep --strict --verbose=2 "$APP"
  echo "    Signature valid"
else
  echo "==> Skipping code signing (BLAZE_SIGNING_IDENTITY not set)"
fi

# --- Notarization ---
if sign_enabled && notarize_enabled; then
  echo "==> Notarizing app..."

  # Create a zip for notarization (notarytool requires zip/dmg/pkg)
  NOTARIZE_ZIP="$DIST/${APP_NAME}-notarize.zip"
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$NOTARIZE_ZIP"

  # Submit and wait
  echo "    Submitting to Apple (this may take a few minutes)..."
  xcrun notarytool submit "$NOTARIZE_ZIP" \
    --keychain-profile "$NOTARIZE_PROFILE" \
    --wait

  # Clean up notarization zip
  rm -f "$NOTARIZE_ZIP"

  # Staple the ticket to the app
  echo "==> Stapling ticket to app..."
  xcrun stapler staple "$APP"

  # Verify stapling
  xcrun stapler validate "$APP"
  echo "    Notarization complete"
else
  if sign_enabled; then
    echo "==> Skipping notarization (BLAZE_NOTARIZE_PROFILE not set)"
  fi
fi

# --- Create ZIP ---
ZIP="$DIST/${APP_NAME}-macOS-${VER}-universal.zip"
rm -f "$ZIP"

echo "==> Creating distribution ZIP: $ZIP"
cd "$DIST"
ditto -c -k --sequesterRsrc --keepParent "${APP_NAME}.app" "$(basename "$ZIP")"

LATEST_ZIP="$DIST/${APP_NAME}-latest-macOS-universal.zip"
cp -f "$ZIP" "$LATEST_ZIP"
echo "    Latest ZIP: $LATEST_ZIP"

# --- Create DMG ---
"$REPO_ROOT/scripts/make-dmg.sh" "$APP" "$VERSION"

echo "==> Done."
echo "App: $APP"
echo "Zip: $ZIP"
