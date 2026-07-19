#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$PROJECT_ROOT/dist/Wallflow.app"
CONTENTS_PATH="$APP_PATH/Contents"
ICONSET_PATH="$PROJECT_ROOT/.build/Wallflow.iconset"

cd "$PROJECT_ROOT"
swift build -c release --arch arm64 --arch x86_64 --product Wallflow
BIN_PATH="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

rm -rf "$APP_PATH"
mkdir -p "$CONTENTS_PATH/MacOS" "$CONTENTS_PATH/Resources"

cp "$BIN_PATH/Wallflow" "$CONTENTS_PATH/MacOS/Wallflow"
cp "$PROJECT_ROOT/Packaging/Info.plist" "$CONTENTS_PATH/Info.plist"

rm -rf "$ICONSET_PATH"
mkdir -p "$ICONSET_PATH"

sips -z 16 16 "$PROJECT_ROOT/Resources/AppIcon.png" --out "$ICONSET_PATH/icon_16x16.png" >/dev/null
sips -z 32 32 "$PROJECT_ROOT/Resources/AppIcon.png" --out "$ICONSET_PATH/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$PROJECT_ROOT/Resources/AppIcon.png" --out "$ICONSET_PATH/icon_32x32.png" >/dev/null
sips -z 64 64 "$PROJECT_ROOT/Resources/AppIcon.png" --out "$ICONSET_PATH/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$PROJECT_ROOT/Resources/AppIcon.png" --out "$ICONSET_PATH/icon_128x128.png" >/dev/null
sips -z 256 256 "$PROJECT_ROOT/Resources/AppIcon.png" --out "$ICONSET_PATH/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$PROJECT_ROOT/Resources/AppIcon.png" --out "$ICONSET_PATH/icon_256x256.png" >/dev/null
sips -z 512 512 "$PROJECT_ROOT/Resources/AppIcon.png" --out "$ICONSET_PATH/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$PROJECT_ROOT/Resources/AppIcon.png" --out "$ICONSET_PATH/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$PROJECT_ROOT/Resources/AppIcon.png" --out "$ICONSET_PATH/icon_512x512@2x.png" >/dev/null

iconutil -c icns "$ICONSET_PATH" -o "$CONTENTS_PATH/Resources/AppIcon.icns"
plutil -lint "$CONTENTS_PATH/Info.plist" >/dev/null
codesign --force --deep --sign - "$APP_PATH" >/dev/null

echo "$APP_PATH"
