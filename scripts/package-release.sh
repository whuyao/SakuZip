#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_APP="$PROJECT_DIR/.build/YCompress.app"
ROOT_APP="$PROJECT_DIR/YCompress.app"
ROOT_ZIP="$PROJECT_DIR/YCompress-macOS-arm64.zip"
DIST_DIR="$PROJECT_DIR/dist"
TEMP_DIR="$(mktemp -d /private/tmp/ycompress-release.XXXXXX)"
RELEASE_APP="$TEMP_DIR/YCompress.app"
ZIP_STAGE="$TEMP_DIR/zip"
DMG_STAGE="$TEMP_DIR/dmg"

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

remove_file_provider_attributes() {
  local target="$1"
  xattr -cr "$target"
  if xattr "$target" | /usr/bin/grep -qx "com.apple.FinderInfo"; then
    xattr -d com.apple.FinderInfo "$target"
  fi
  if xattr "$target" | /usr/bin/grep -qx "com.apple.fileprovider.fpfs#P"; then
    xattr -d "com.apple.fileprovider.fpfs#P" "$target"
  fi
}

"$PROJECT_DIR/scripts/build-app.sh"

VERSION="$(/usr/libexec/PlistBuddy \
  -c "Print :CFBundleShortVersionString" \
  "$BUILD_APP/Contents/Info.plist")"
DMG_NAME="YCompress-${VERSION}-macOS-arm64.dmg"
ROOT_DMG="$PROJECT_DIR/$DMG_NAME"

/usr/bin/ditto "$BUILD_APP" "$RELEASE_APP"
remove_file_provider_attributes "$RELEASE_APP"
codesign --force --deep --sign - "$RELEASE_APP"
codesign --verify --deep --strict --verbose=2 "$RELEASE_APP"

rm -rf "$ROOT_APP"
/usr/bin/ditto "$RELEASE_APP" "$ROOT_APP"
remove_file_provider_attributes "$ROOT_APP"
codesign --force --deep --sign - "$ROOT_APP"

mkdir -p "$ZIP_STAGE" "$DMG_STAGE" "$DIST_DIR"
/usr/bin/ditto "$RELEASE_APP" "$ZIP_STAGE/YCompress.app"
/usr/bin/ditto "$RELEASE_APP" "$DMG_STAGE/YCompress.app"
/bin/ln -s /Applications "$DMG_STAGE/Applications"
/bin/cp "$PROJECT_DIR/docs/INSTALL.md" "$DMG_STAGE/安装说明.md"
/bin/cp "$PROJECT_DIR/docs/USER_GUIDE.md" "$DMG_STAGE/使用手册.md"

for oldDMG in "$PROJECT_DIR"/YCompress-*-macOS-arm64.dmg; do
  if [[ -f "$oldDMG" && "$oldDMG" != "$ROOT_DMG" ]]; then
    rm -f "$oldDMG"
  fi
done
rm -f "$ROOT_ZIP" "$ROOT_DMG"
(
  cd "$ZIP_STAGE"
  /usr/bin/zip -q -r -X "$ROOT_ZIP" YCompress.app
)

/usr/bin/hdiutil create \
  -volname "YCompress $VERSION" \
  -srcfolder "$DMG_STAGE" \
  -ov \
  -format UDZO \
  "$ROOT_DMG"

/usr/bin/hdiutil verify "$ROOT_DMG"

/bin/cp "$PROJECT_DIR/docs/INSTALL.md" "$PROJECT_DIR/安装说明.md"
/bin/cp "$PROJECT_DIR/docs/USER_GUIDE.md" "$PROJECT_DIR/使用手册.md"
(
  cd "$PROJECT_DIR"
  /usr/bin/shasum -a 256 \
    "YCompress-macOS-arm64.zip" \
    "$DMG_NAME" > SHA256SUMS
)

rm -rf "$DIST_DIR/YCompress.app"
/usr/bin/ditto "$RELEASE_APP" "$DIST_DIR/YCompress.app"
/bin/cp "$ROOT_ZIP" "$DIST_DIR/YCompress-macOS-arm64.zip"
for oldDMG in "$DIST_DIR"/YCompress-*-macOS-arm64.dmg; do
  if [[ -f "$oldDMG" && "$oldDMG" != "$DIST_DIR/$DMG_NAME" ]]; then
    rm -f "$oldDMG"
  fi
done
/bin/cp "$ROOT_DMG" "$DIST_DIR/$DMG_NAME"
/bin/cp "$PROJECT_DIR/SHA256SUMS" "$DIST_DIR/SHA256SUMS"

# ditto 会保留源 Bundle 的目录时间；刷新顶层时间，避免 Finder 把新 App 显示成旧版本。
/usr/bin/touch "$ROOT_APP" "$DIST_DIR/YCompress.app"

echo "发布文件已生成："
echo "$ROOT_APP"
echo "$ROOT_ZIP"
echo "$ROOT_DMG"
echo "$PROJECT_DIR/SHA256SUMS"
echo "$PROJECT_DIR/安装说明.md"
echo "$PROJECT_DIR/使用手册.md"
