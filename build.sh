#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
NAME="PortPeek"
VERSION="${VERSION:-1.1.0}"
APP="dist/$NAME.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -target arm64-apple-macos13.0 -O Sources/*.swift -o "$APP/Contents/MacOS/$NAME"
cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>io.github.leonsuv.portpeek</string>
<key>CFBundleName</key><string>$NAME</string><key>CFBundleExecutable</key><string>$NAME</string>
<key>CFBundlePackageType</key><string>APPL</string><key>CFBundleShortVersionString</key><string>$VERSION</string><key>CFBundleVersion</key><string>$VERSION</string>
<key>CFBundleIconFile</key><string>AppIcon</string><key>LSMinimumSystemVersion</key><string>13.0</string><key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP"
"$APP/Contents/MacOS/$NAME" --self-test
codesign --verify --deep --strict "$APP"
