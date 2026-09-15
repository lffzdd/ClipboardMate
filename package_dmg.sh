#!/bin/bash
# 打包 ClipboardMate.dmg (纯原生 hdiutil，包含 /Applications 软链接，支持拖拽安装)
set -euo pipefail
cd "$(dirname "$0")"

CACHE_DIR=".cache"
mkdir -p "$CACHE_DIR"

echo "🔨 正在编译 ClipboardMate..."
swiftc -O -module-cache-path "$CACHE_DIR" Sources/ClipboardMate/*.swift -o "$CACHE_DIR/ClipboardMate"

BUILD_DIR="build"
APP="$BUILD_DIR/ClipboardMate.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$CACHE_DIR/ClipboardMate" "$APP/Contents/MacOS/ClipboardMate"

cat > "$APP/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.williamlao.clipboardmate</string>
    <key>CFBundleName</key>
    <string>ClipboardMate</string>
    <key>CFBundleExecutable</key>
    <string>ClipboardMate</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2</string>
    <key>CFBundleVersion</key>
    <string>3</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

codesign --force -s - -r '=designated => identifier "com.williamlao.clipboardmate"' "$APP"
echo "✅ App 构建完成: $PWD/$APP"

# 准备 DMG 临时分发目录
DMG_STAGING="$BUILD_DIR/dmg_staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

DMG_OUTPUT="$BUILD_DIR/ClipboardMate.dmg"
rm -f "$DMG_OUTPUT"

echo "📦 正在生成 DMG 安装包..."
hdiutil create -volname "ClipboardMate" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG_OUTPUT"
rm -rf "$DMG_STAGING"

echo "🎉 DMG 打包完成: $PWD/$DMG_OUTPUT"
