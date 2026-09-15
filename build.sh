#!/bin/bash
# 构建 ClipboardMate.app
set -euo pipefail
cd "$(dirname "$0")"

CACHE_DIR=".cache"
mkdir -p "$CACHE_DIR"

echo "🔨 正在编译 ClipboardMate..."
swiftc -O -module-cache-path "$CACHE_DIR" Sources/ClipboardMate/*.swift -o "$CACHE_DIR/ClipboardMate"

APP="build/ClipboardMate.app"
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
echo "✅ 构建完成: $PWD/$APP"

# 部署至 /Applications，并清除 build/ 目录下的副本与防索引标记
DEST="/Applications/ClipboardMate.app"
echo "📦 正在同步部署至 $DEST..."
rm -rf "$DEST"
cp -R "$APP" "$DEST"
codesign --force -s - -r '=designated => identifier "com.williamlao.clipboardmate"' "$DEST"
rm -rf "$APP"
touch build/.metadata_never_index
echo "🎉 部署完成：$DEST (已清理工程临时副本，系统只保留唯一正本)"
