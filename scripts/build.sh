#!/bin/bash
set -e

cd "$(dirname "$0")/.."
PROJECT_ROOT="$(pwd)"
cd ListenType

echo "Building ListenType..."
swift build -c release 2>&1

APP_DIR="/Applications/ListenType.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
mkdir -p "$MACOS" "$RESOURCES"

# Copy binary
cp .build/release/ListenType "$MACOS/ListenType"

# Copy Info.plist
cp Sources/ListenType/Info.plist "$CONTENTS/Info.plist"

# Copy icon
cp Sources/ListenType/AppIcon.icns "$RESOURCES/AppIcon.icns"

# Copy whisper-cli (static build)
WHISPER_CLI="/private/tmp/whisper.cpp/build/bin/whisper-cli"
if [ -f "$WHISPER_CLI" ]; then
    cp "$WHISPER_CLI" "$RESOURCES/whisper-cli"
    chmod +x "$RESOURCES/whisper-cli"
    echo "Bundled whisper-cli from $WHISPER_CLI"
else
    echo "WARNING: whisper-cli not found at $WHISPER_CLI"
    echo "Run: cd /private/tmp/whisper.cpp && mkdir -p build && cd build && cmake .. -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release -DGGML_METAL=ON && cmake --build . --config Release -j\$(sysctl -n hw.ncpu)"
fi

# Code sign (ad-hoc)
codesign --force --sign - --identifier com.listentype.app --deep "$APP_DIR"

echo ""
echo "Built: $APP_DIR"
echo "Run:   open $APP_DIR"
