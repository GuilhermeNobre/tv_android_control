#!/bin/bash
# Builds the app and assembles macos/build/TVControl.app (only needs the Command Line Tools).
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(cd .. && pwd)"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/TVControl"

APP=build/TVControl.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/TVControl"

# App icon: draw the master PNG in code and assemble the .icns (16 to 1024 px, with @2x).
ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET" && mkdir -p "$ICONSET" "$APP/Contents/Resources"
swift icon/make-icon.swift build/icon-1024.png
for s in 16 32 128 256 512; do
    sips -z $s $s build/icon-1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) build/icon-1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>TV Control</string>
  <key>CFBundleDisplayName</key><string>TV Control</string>
  <key>CFBundleIdentifier</key><string>local.tvcontrol.app</string>
  <key>CFBundleExecutable</key><string>TVControl</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
  <key>NSLocalNetworkUsageDescription</key><string>Controlar a TV na rede local.</string>
  <key>TVProjectRoot</key><string>$ROOT</string>
</dict></plist>
PLIST

codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Pronto: $(pwd)/$APP"
