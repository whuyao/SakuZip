#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
APP_DIR="$BUILD_DIR/SakuZip.app"
TOOLCHAIN_DIR="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain"
SWIFT_BIN="${SAKUZIP_SWIFT_BIN:-$TOOLCHAIN_DIR/usr/bin/swift}"
MACOS_SDK="${SAKUZIP_MACOS_SDK:-/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk}"
MODULE_CACHE="$BUILD_DIR/ModuleCache"
STAGE_ROOT="$(mktemp -d /private/tmp/sakuzip-app-build.XXXXXX)"
STAGE_APP="$STAGE_ROOT/SakuZip.app"

cleanup() {
  rm -rf "$STAGE_ROOT"
}
trap cleanup EXIT

# Remove the legacy bundle left by builds from before the SakuZip rename.
rm -rf "$BUILD_DIR/YCompress.app"

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

BINARY_PATH="$(env \
  SDKROOT="$MACOS_SDK" \
  CLANG_MODULE_CACHE_PATH="$MODULE_CACHE" \
  SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE" \
  "$SWIFT_BIN" build \
  --disable-sandbox \
  --configuration release \
  --scratch-path "$BUILD_DIR" \
  --show-bin-path)/SakuZip"

mkdir -p "$STAGE_APP/Contents/MacOS" "$STAGE_APP/Contents/Resources"
cp "$PROJECT_DIR/Resources/Info.plist" "$STAGE_APP/Contents/Info.plist"
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$STAGE_APP/Contents/Resources/AppIcon.icns"
cp "$PROJECT_DIR/THIRD_PARTY_NOTICES.md" "$STAGE_APP/Contents/Resources/Third-Party-Notices.md"
cp "$PROJECT_DIR/Sources/CSakuZipArchive/minizip/LICENSE" \
  "$STAGE_APP/Contents/Resources/minizip-ng-LICENSE.txt"
cp "$BINARY_PATH" "$STAGE_APP/Contents/MacOS/SakuZip"
for localization in zh-Hans en ja; do
  /usr/bin/ditto \
    "$PROJECT_DIR/Resources/$localization.lproj" \
    "$STAGE_APP/Contents/Resources/$localization.lproj"
done
chmod +x "$STAGE_APP/Contents/MacOS/SakuZip"

xattr -cr "$STAGE_APP"
codesign --force --deep --sign - "$STAGE_APP"
codesign --verify --deep --strict --verbose=2 "$STAGE_APP"

rm -rf "$APP_DIR"
/usr/bin/ditto "$STAGE_APP" "$APP_DIR"
xattr -cr "$APP_DIR"
echo "$APP_DIR"
