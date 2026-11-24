#!/bin/bash
# Build "MHGU Charms RNG.app" into dist/. Requires the Xcode command-line tools.
#
#   ./build_app.sh               build for this Mac's architecture
#   ./build_app.sh --universal   build for Apple Silicon and Intel, and zip it for a release
set -euo pipefail
cd "$(dirname "$0")"

VERSION="1.0.1"
UNIVERSAL=0
[[ "${1:-}" == "--universal" ]] && UNIVERSAL=1

ARGS=(-c release --product MHXXRNG)
(( UNIVERSAL )) && ARGS+=(--arch arm64 --arch x86_64)
swift build "${ARGS[@]}"
BIN="$(swift build "${ARGS[@]}" --show-bin-path)/MHXXRNG"

APP="dist/MHGU Charms RNG.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MHXXRNG"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>MHGU Charms RNG</string>
  <key>CFBundleDisplayName</key><string>MHGU Charms RNG</string>
  <key>CFBundleIdentifier</key><string>local.mhgu-charms-rng</string>
  <key>CFBundleExecutable</key><string>MHXXRNG</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

# Ad-hoc signature so macOS will run it. (Not a Developer ID signature, so a downloaded
# copy shows a security prompt the first time it's opened. See README.)
codesign --force --sign - "$APP"
echo "Built: $(pwd)/$APP ($(lipo -archs "$APP/Contents/MacOS/MHXXRNG"))"

if (( UNIVERSAL )); then
  ZIP="dist/MHGU-Charms-RNG-${VERSION}-macOS.zip"
  rm -f "$ZIP"
  ditto -c -k --keepParent "$APP" "$ZIP"
  echo "Zipped: $(pwd)/$ZIP"
fi
