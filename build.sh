#!/bin/bash
# 构建 ClipboardMate.app
set -euo pipefail
cd "$(dirname "$0")"

BUNDLE_ID="com.williamlao.clipboardmate"
APP_NAME="ClipboardMate"
DEST="/Applications/ClipboardMate.app"

was_running=false
if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    was_running=true
    echo "🔄 检测到 $APP_NAME 正在运行，正在退出…"
    osascript -e "tell application id \"$BUNDLE_ID\" to quit" 2>/dev/null \
        || osascript -e "tell application \"$APP_NAME\" to quit" 2>/dev/null \
        || killall "$APP_NAME" 2>/dev/null || true
    for _ in $(seq 1 50); do
        pgrep -x "$APP_NAME" >/dev/null 2>&1 || break
        sleep 0.1
    done
    if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
        echo "⚠️  未能完全退出 $APP_NAME，部署可能失败；请手动退出后重试。"
        exit 1
    fi
fi

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
    <string>4</string>
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
echo "📦 正在同步部署至 $DEST..."
rm -rf "$DEST"
cp -R "$APP" "$DEST"
codesign --force -s - -r '=designated => identifier "com.williamlao.clipboardmate"' "$DEST"
rm -rf "$APP"
touch build/.metadata_never_index
echo "🎉 部署完成：$DEST (已清理工程临时副本，系统只保留唯一正本)"

if [[ "$was_running" == true ]]; then
    echo "🚀 正在重新启动 ${APP_NAME}…"
    open -a "$DEST"
fi
