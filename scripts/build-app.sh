#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
APP_DIR="$BUILD_DIR/YCompress.app"
TOOLCHAIN_DIR="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain"
SWIFT_BIN="$TOOLCHAIN_DIR/usr/bin/swift"
MACOS_SDK="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
MODULE_CACHE="$BUILD_DIR/ModuleCache"

if [[ ! -x "$SWIFT_BIN" ]]; then
  echo "未找到 Xcode Swift 工具链，请先从 App Store 安装 Xcode。" >&2
  exit 1
fi

mkdir -p "$MODULE_CACHE"
"$PROJECT_DIR/scripts/make-icon.sh"
env \
  SDKROOT="$MACOS_SDK" \
  CLANG_MODULE_CACHE_PATH="$MODULE_CACHE" \
  SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE" \
  "$SWIFT_BIN" build \
    --disable-sandbox \
    --configuration release \
    --scratch-path "$BUILD_DIR"

BINARY_PATH="$("$SWIFT_BIN" build \
  --disable-sandbox \
  --configuration release \
  --scratch-path "$BUILD_DIR" \
  --show-bin-path)/YCompress"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
cp "$BINARY_PATH" "$APP_DIR/Contents/MacOS/YCompress"
chmod +x "$APP_DIR/Contents/MacOS/YCompress"

xattr -cr "$APP_DIR"
codesign --force --deep --sign - "$APP_DIR"
echo "$APP_DIR"
