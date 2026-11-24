#!/bin/bash
# Build "MHGU Charms RNG.app" into mac-app/dist. Requires Xcode command-line tools.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --product MHXXRNG

APP="dist/MHGU Charms RNG.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/MHXXRNG "$APP/Contents/MacOS/MHXXRNG"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>MHGU Charms RNG</string>
  <key>CFBundleDisplayName</key><string>MHGU Charms RNG</string>
  <key>CFBundleIdentifier</key><string>local.mhgu-charms-rng</string>
  <key>CFBundleExecutable</key><string>MHXXRNG</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

# Ad-hoc signature so macOS will run it locally.
codesign --force --sign - "$APP"
echo "Built: $(pwd)/$APP"
