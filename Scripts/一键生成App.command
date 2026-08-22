#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"
APP_NAME="Rock专用YouTube下载器"
APP="$PWD/$APP_NAME.app"
BUILD="$PWD/.build"

echo "=========================================="
echo "   正在生成 $APP_NAME.app"
echo "=========================================="

if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "没有检测到苹果编译工具。"
  echo "请先在终端执行：xcode-select --install"
  echo "安装完成后，再双击这个文件。"
  read -p "按回车关闭..."
  exit 1
fi

rm -rf "$APP" "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$BUILD/icon.iconset"

cp Info.plist "$APP/Contents/Info.plist"

# 生成苹果 App 图标所需尺寸
for spec in "16 16x16" "32 16x16@2x" "32 32x32" "64 32x32@2x" "128 128x128" "256 128x128@2x" "256 256x256" "512 256x256@2x" "512 512x512" "1024 512x512@2x"; do
  set -- $spec
  px=$1; name=$2
  sips -z "$px" "$px" Assets/AppIcon-1024.png --out "$BUILD/icon.iconset/icon_${name}.png" >/dev/null
 done
iconutil -c icns "$BUILD/icon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"

SDK=$(xcrun --sdk macosx --show-sdk-path)
xcrun swiftc Sources/YTDownloader.swift \
  -o "$APP/Contents/MacOS/YTDownloader" \
  -sdk "$SDK" \
  -framework SwiftUI -framework AppKit \
  -parse-as-library

chmod +x "$APP/Contents/MacOS/YTDownloader"

# 本机临时签名，减少 macOS 启动拦截
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

echo ""
echo "✅ 已生成：$APP"
echo "你现在可以直接双击运行，也可以拖进“应用程序”文件夹。"
open "$PWD"
read -p "按回车关闭..."
