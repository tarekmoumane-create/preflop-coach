#!/bin/bash
# Builds "Preflop Coach.app" with plain swiftc (works with the Command Line Tools alone).
#   ./build.sh            build into ./build
#   ./build.sh install    also copy to /Applications and launch it
set -euo pipefail
cd "$(dirname "$0")"

TARGET="$(uname -m)-apple-macos13.0"
OBJ=build/obj
APP="build/Preflop Coach.app"
mkdir -p "$OBJ"

echo "Compiling core…"
swiftc -O -target "$TARGET" -parse-as-library -module-name PreflopCore \
    -emit-module -emit-module-path "$OBJ/PreflopCore.swiftmodule" \
    -emit-library -static -o "$OBJ/libPreflopCore.a" Sources/PreflopCore/*.swift

echo "Checking core…"
swiftc -O -target "$TARGET" -I "$OBJ" -L "$OBJ" -lPreflopCore Sources/corecheck/main.swift -o "$OBJ/corecheck"
"$OBJ/corecheck"

echo "Compiling app…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O -target "$TARGET" -parse-as-library -I "$OBJ" -L "$OBJ" -lPreflopCore Sources/PreflopCoach/*.swift \
    -o "$APP/Contents/MacOS/PreflopCoach"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Preflop Coach</string>
    <key>CFBundleDisplayName</key><string>Preflop Coach</string>
    <key>CFBundleIdentifier</key><string>local.preflopcoach</string>
    <key>CFBundleExecutable</key><string>PreflopCoach</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

# A local self-signed certificate keeps the app's identity stable across rebuilds, so
# macOS doesn't forget the Screen Recording permission every time. Ad hoc otherwise.
IDENTITY="Preflop Coach Local Signing"
if security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then
    codesign --force --sign "$IDENTITY" "$APP"
else
    codesign --force --sign - "$APP"
fi
echo "Built $APP"

if [[ "${1:-}" == "install" ]]; then
    pkill -x PreflopCoach 2>/dev/null || true
    rm -rf "/Applications/Preflop Coach.app"
    cp -R "$APP" /Applications/
    open "/Applications/Preflop Coach.app"
    echo "Installed and launched. Look for ♠︎ in the menu bar."
fi
