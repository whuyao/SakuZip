#!/bin/zsh
set -euo pipefail
setopt NULL_GLOB

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_APP="$PROJECT_DIR/.build/YCompress.app"
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
DIST_APP="$DIST_DIR/YCompress.app"
DIST_ZIP="$DIST_DIR/YCompress-macOS-arm64.zip"
DIST_DMG="$DIST_DIR/$DMG_NAME"

/usr/bin/ditto "$BUILD_APP" "$RELEASE_APP"
remove_file_provider_attributes "$RELEASE_APP"
codesign --force --deep --sign - "$RELEASE_APP"
codesign --verify --deep --strict --verbose=2 "$RELEASE_APP"

mkdir -p "$ZIP_STAGE" "$DMG_STAGE" "$DIST_DIR"
/usr/bin/ditto "$RELEASE_APP" "$ZIP_STAGE/YCompress.app"
/usr/bin/ditto "$RELEASE_APP" "$DMG_STAGE/YCompress.app"
/bin/ln -s /Applications "$DMG_STAGE/Applications"
/bin/cp "$PROJECT_DIR/docs/INSTALL.md" "$DMG_STAGE/安装说明.md"
/bin/cp "$PROJECT_DIR/docs/USER_GUIDE.md" "$DMG_STAGE/使用手册.md"
/bin/cp "$PROJECT_DIR/docs/INSTALL.en.md" "$DMG_STAGE/Installation Guide (English).md"
/bin/cp "$PROJECT_DIR/docs/USER_GUIDE.en.md" "$DMG_STAGE/User Guide (English).md"
/bin/cp "$PROJECT_DIR/docs/INSTALL.ja.md" "$DMG_STAGE/インストールガイド（日本語）.md"
/bin/cp "$PROJECT_DIR/docs/USER_GUIDE.ja.md" "$DMG_STAGE/ユーザーガイド（日本語）.md"

rm -rf "$DIST_APP"
/usr/bin/ditto "$RELEASE_APP" "$DIST_APP"
remove_file_provider_attributes "$DIST_APP"
codesign --force --deep --sign - "$DIST_APP"

for oldDMG in "$DIST_DIR"/YCompress-*-macOS-arm64.dmg; do
  if [[ -f "$oldDMG" && "$oldDMG" != "$DIST_DMG" ]]; then
    rm -f "$oldDMG"
  fi
done
rm -f "$DIST_ZIP" "$DIST_DMG"
(
  cd "$ZIP_STAGE"
  /usr/bin/zip -q -r -X "$DIST_ZIP" YCompress.app
)

/usr/bin/hdiutil create \
  -volname "YCompress $VERSION" \
  -srcfolder "$DMG_STAGE" \
  -ov \
  -format UDZO \
  "$DIST_DMG"

/usr/bin/hdiutil verify "$DIST_DMG"

(
  cd "$DIST_DIR"
  /usr/bin/shasum -a 256 \
    "YCompress-macOS-arm64.zip" \
    "$DMG_NAME" > "SHA256SUMS"
)

# ditto 会保留源 Bundle 的目录时间；刷新顶层时间，避免 Finder 把新 App 显示成旧版本。
/usr/bin/touch "$DIST_APP"
remove_file_provider_attributes "$DIST_APP"
codesign --force --deep --sign - "$DIST_APP"
codesign --verify --deep --strict --verbose=2 "$DIST_APP"

echo "发布文件已生成："
echo "$DIST_APP"
echo "$DIST_ZIP"
echo "$DIST_DMG"
echo "$DIST_DIR/SHA256SUMS"
