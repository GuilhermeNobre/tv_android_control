#!/bin/bash
# Compila o app e monta macos/build/TVControl.app (precisa só das Command Line Tools).
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(cd .. && pwd)"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/TVControl"

APP=build/TVControl.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/TVControl"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>TV Control</string>
  <key>CFBundleDisplayName</key><string>TV Control</string>
  <key>CFBundleIdentifier</key><string>local.tvcontrol.app</string>
  <key>CFBundleExecutable</key><string>TVControl</string>
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
