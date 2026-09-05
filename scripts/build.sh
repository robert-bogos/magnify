#!/bin/bash
# Builds the magnifier with swiftc directly (works with Command Line Tools only —
# no full Xcode required). Produces Magnify.app, ad-hoc signed.
set -euo pipefail
cd "$(dirname "$0")/.."

SDK="$(xcrun --sdk macosx --show-sdk-path)"
TARGET="arm64-apple-macos13.0"
OUT=".build/manual"
mkdir -p "$OUT"

echo "▸ Compiling MagnifyCore (pure logic)…"
swiftc -sdk "$SDK" -target "$TARGET" -O -wmo -parse-as-library \
    -module-name MagnifyCore \
    -emit-module -emit-module-path "$OUT/MagnifyCore.swiftmodule" \
    -c Sources/MagnifyCore/*.swift -o "$OUT/MagnifyCore.o"

echo "▸ Compiling magnify (AppKit + ScreenCaptureKit)…"
swiftc -sdk "$SDK" -target "$TARGET" -O \
    -module-name magnify \
    -I "$OUT" \
    -framework ScreenCaptureKit \
    -framework Carbon \
    Sources/magnify/*.swift "$OUT/MagnifyCore.o" \
    -o "$OUT/magnify"

APP="Magnify.app"
echo "▸ Bundling ${APP} ..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$OUT/magnify" "$APP/Contents/MacOS/magnify"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Magnify</string>
    <key>CFBundleDisplayName</key><string>Magnify</string>
    <key>CFBundleIdentifier</key><string>com.rbogos.magnify</string>
    <key>CFBundleExecutable</key><string>magnify</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "▸ Ad-hoc signing…"
codesign --force --sign - "$APP"

echo "✓ Done."
echo "  Run:  ./magnify --zoom 2 --size 320"
echo "  First launch: grant Screen Recording in System Settings — the lens appears within ~2s."
