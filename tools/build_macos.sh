#!/bin/bash
# No export-template download required: package the installed MIT-licensed Godot engine.
# Larger than a release-template build, but entirely self-contained and relocatable.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
BUILD="$ROOT/builds"
APP="$BUILD/Road Rage.app"
[ -x "$GODOT" ] || { echo "Set GODOT_BIN to your Godot executable."; exit 1; }
mkdir -p "$BUILD"
"$GODOT" --headless --path "$ROOT" --editor --import --quit
"$GODOT" --headless --path "$ROOT" --script tools/engine_licenses.gd
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
"$GODOT" --headless --path "$ROOT" --export-pack macOS "$APP/Contents/Resources/game.pck"
lipo "$GODOT" -thin arm64 -output "$APP/Contents/MacOS/RoadRageEngine"
xcrun clang -arch arm64 -Os "$ROOT/tools/app_launcher.c" -o "$APP/Contents/MacOS/RoadRage"
cp "$ROOT/assets/GODOT_LICENSES.txt" "$APP/Contents/Resources/GODOT_LICENSES.txt"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Road Rage</string>
<key>CFBundleDisplayName</key><string>Road Rage · 极限狂飙</string>
<key>CFBundleIdentifier</key><string>local.wayne.roadrage</string>
<key>CFBundleExecutable</key><string>RoadRage</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>4.4.0</string>
<key>CFBundleVersion</key><string>4.4.0</string>
<key>CFBundleIconFile</key><string>GameIcon</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSApplicationCategoryType</key><string>public.app-category.racing-games</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
ICONSET="$BUILD/GameIcon.iconset"
mkdir -p "$ICONSET"
"$GODOT" --headless --path "$ROOT" --script tools/export_icon.gd
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/GameIcon.icns"
codesign --force --sign - "$APP/Contents/MacOS/RoadRageEngine"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$BUILD/RoadRage-macOS-AppleSilicon.zip"
printf '\nReady: %s\n' "$APP"
