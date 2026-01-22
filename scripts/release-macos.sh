#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 v0.1.0"
  exit 1
fi
VER="${VERSION#v}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG_DIR="$REPO_ROOT/Blaze"   # <-- your SwiftPM package folder
APP_NAME="Blaze"
BUNDLE_ID="dev.getblaze.Blaze"
MIN_MACOS="13.0"
ICON_ICNS="$PKG_DIR/Resources/AppIcon.icns"

cd "$PKG_DIR"

echo "==> Building release with SwiftPM…"
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
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
  echo "==> Copying app icon: $ICON_ICNS"
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

ZIP="$DIST/${APP_NAME}-macOS-${VER}-arm64.zip"
rm -f "$ZIP"

echo "==> Zipping: $ZIP"
cd "$DIST"
ditto -c -k --sequesterRsrc --keepParent "${APP_NAME}.app" "$(basename "$ZIP")"
LATEST_ZIP="$DIST/${APP_NAME}-latest-macOS-arm64.zip"
cp -f "$ZIP" "$LATEST_ZIP"
echo "Latest Zip: $LATEST_ZIP"


# Create DMG installer
"$REPO_ROOT/scripts/make-dmg.sh" "$APP" "$VERSION"


echo "==> Done."
echo "App: $APP"
echo "Zip: $ZIP"

