#!/bin/bash
# Builds "Preflop Coach.app" with plain swiftc (works with the Command Line Tools alone).
#   ./build.sh            build into ./build
#   ./build.sh install    also copy to /Applications and launch it
#   ./build.sh release    also package build/Preflop Coach.zip for a GitHub release
set -euo pipefail
cd "$(dirname "$0")"

OBJ=build/obj
APP="build/Preflop Coach.app"
rm -rf "$APP" "$OBJ"
mkdir -p "$APP/Contents/MacOS"

# Universal binary: built once per architecture, then joined with lipo.
for ARCH in arm64 x86_64; do
    TARGET="$ARCH-apple-macos13.0"
    DIR="$OBJ/$ARCH"
    mkdir -p "$DIR"

    echo "Compiling core ($ARCH)…"
    swiftc -O -target "$TARGET" -parse-as-library -module-name PreflopCore \
        -emit-module -emit-module-path "$DIR/PreflopCore.swiftmodule" \
        -emit-library -static -o "$DIR/libPreflopCore.a" Sources/PreflopCore/*.swift

    echo "Compiling app ($ARCH)…"
    swiftc -O -target "$TARGET" -parse-as-library -I "$DIR" -L "$DIR" -lPreflopCore Sources/PreflopCoach/*.swift \
        -o "$DIR/PreflopCoach"
done

echo "Checking core…"
NATIVE="$OBJ/$(uname -m)"
swiftc -O -target "$(uname -m)-apple-macos13.0" -I "$NATIVE" -L "$NATIVE" -lPreflopCore Sources/corecheck/main.swift -o "$OBJ/corecheck"
"$OBJ/corecheck"

lipo -create "$OBJ/arm64/PreflopCoach" "$OBJ/x86_64/PreflopCoach" -output "$APP/Contents/MacOS/PreflopCoach"

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

if [[ "${1:-}" == "release" ]]; then
    # A zip that keeps the bundle intact, ready to attach to a GitHub release.
    rm -f "build/Preflop-Coach.zip"
    ditto -c -k --keepParent "$APP" "build/Preflop-Coach.zip"
    echo "Packaged build/Preflop-Coach.zip"
fi
