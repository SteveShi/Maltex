#!/bin/bash

# Configuration
APP_NAME="Maltex"
BUNDLE_ID="app.maltex.native"
BUNDLE_PATH="${APP_NAME}.app"
# Use the icon from the assets in the repo
ICON_PNG="Maltex/Assets.xcassets/AppIcon.appiconset/icon.png"

# Get the script directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

ARCH="${1:-arm64}"

echo "🚀 Starting COMPLETE build and bundle process for ${APP_NAME} (${ARCH})..."

# 1. Build the Swift package in release mode
export MACOSX_DEPLOYMENT_TARGET=13.0
swift build -c release --arch ${ARCH}

if [ $? -ne 0 ]; then
    echo "❌ Swift build failed."
    exit 1
fi

# 2. Setup .app structure
echo "📂 Creating bundle structure..."
rm -rf "${BUNDLE_PATH}"
mkdir -p "${BUNDLE_PATH}/Contents/MacOS"
mkdir -p "${BUNDLE_PATH}/Contents/Resources"
mkdir -p "${BUNDLE_PATH}/Contents/PlugIns"

# 3. Copy binary
echo "📦 Copying binary..."
cp ".build/${ARCH}-apple-macosx/release/Maltex" "${BUNDLE_PATH}/Contents/MacOS/Maltex"
chmod +x "${BUNDLE_PATH}/Contents/MacOS/Maltex"

# 3b. Copy Resource Bundle (Crucial for localization)
echo "📦 Copying resources bundle..."
cp -r ".build/${ARCH}-apple-macosx/release/Maltex_Maltex.bundle" "${BUNDLE_PATH}/Contents/Resources/"

# 3c. Build and Package Safari Extension
echo "🧩 Building Safari Extension..."
EXT_NAME="Maltex Extension"
EXT_BUNDLE="${BUNDLE_PATH}/Contents/PlugIns/${EXT_NAME}.appex"
mkdir -p "${EXT_BUNDLE}/Contents/MacOS"
mkdir -p "${EXT_BUNDLE}/Contents/Resources"

# Compile extension handler (Simple stub)
swiftc -emit-executable \
    -sdk $(xcrun --show-sdk-path) \
    -target ${ARCH}-apple-macosx14.0 \
    "MaltexExtension/SafariWebExtensionHandler.swift" \
    -o "${EXT_BUNDLE}/Contents/MacOS/${EXT_NAME}"

# Copy Extension Plist and Resources
cp "MaltexExtension/Info.plist" "${EXT_BUNDLE}/Contents/Info.plist"
cp -r "MaltexExtension/Resources/"* "${EXT_BUNDLE}/Contents/Resources/"

# Ad-hoc Sign the extension
echo "🔐 Signing Safari Extension..."
codesign -s - --force --deep "${EXT_BUNDLE}"

echo "✅ Safari Extension integrated."
# 4. Copy Info.plist
echo "📝 Copying Info.plist..."
cp "Maltex/Info.plist" "${BUNDLE_PATH}/Contents/Info.plist"

# 5. Copy aria2c engine
echo "⚙️ Copying aria2c engine..."
ENGINE_PATH="extra/darwin/arm64/engine/aria2c"
if [ ! -f "$ENGINE_PATH" ]; then
    ENGINE_PATH="extra/darwin/x64/engine/aria2c"
fi

if [ -f "$ENGINE_PATH" ]; then
    cp "$ENGINE_PATH" "${BUNDLE_PATH}/Contents/Resources/aria2c"
    chmod +x "${BUNDLE_PATH}/Contents/Resources/aria2c"
    echo "✅ Engine integrated."
else
    echo "❌ Critical Error: aria2c engine not found."
    exit 1
fi

# 5a. Copy experimental aria2-next engine
echo "⚙️ Copying aria2-next experimental engine..."
NEXT_ENGINE_PATH="extra/darwin/arm64/engine/aria2-next"
if [ ! -f "$NEXT_ENGINE_PATH" ]; then
    NEXT_ENGINE_PATH="extra/darwin/x64/engine/aria2-next"
fi

if [ -f "$NEXT_ENGINE_PATH" ]; then
    cp "$NEXT_ENGINE_PATH" "${BUNDLE_PATH}/Contents/Resources/aria2-next"
    chmod +x "${BUNDLE_PATH}/Contents/Resources/aria2-next"
    echo "✅ Experimental engine integrated."
else
    echo "⚠️ aria2-next experimental engine not found; skipping."
fi

# 5b. Copy aria2.conf
echo "📄 Copying aria2.conf..."
CONF_PATH="extra/darwin/arm64/engine/aria2.conf"
if [ -f "$CONF_PATH" ]; then
    cp "$CONF_PATH" "${BUNDLE_PATH}/Contents/Resources/aria2.conf"
    echo "✅ Config integrated."
fi

# 6. Generate Icon
if [ -f "$ICON_PNG" ]; then
    echo "🎨 Generating AppIcon.icns..."
    mkdir -p Maltex.iconset
    sips -s format png -z 16 16     "$ICON_PNG" --out Maltex.iconset/icon_16x16.png > /dev/null 2>&1
    sips -s format png -z 32 32     "$ICON_PNG" --out Maltex.iconset/icon_16x16@2x.png > /dev/null 2>&1
    sips -s format png -z 32 32     "$ICON_PNG" --out Maltex.iconset/icon_32x32.png > /dev/null 2>&1
    sips -s format png -z 64 64     "$ICON_PNG" --out Maltex.iconset/icon_32x32@2x.png > /dev/null 2>&1
    sips -s format png -z 128 128   "$ICON_PNG" --out Maltex.iconset/icon_128x128.png > /dev/null 2>&1
    sips -s format png -z 256 256   "$ICON_PNG" --out Maltex.iconset/icon_128x128@2x.png > /dev/null 2>&1
    sips -s format png -z 256 256   "$ICON_PNG" --out Maltex.iconset/icon_256x256.png > /dev/null 2>&1
    sips -s format png -z 512 512   "$ICON_PNG" --out Maltex.iconset/icon_256x256@2x.png > /dev/null 2>&1
    sips -s format png -z 512 512   "$ICON_PNG" --out Maltex.iconset/icon_512x512.png > /dev/null 2>&1
    sips -s format png -z 1024 1024 "$ICON_PNG" --out Maltex.iconset/icon_512x512@2x.png > /dev/null 2>&1
    
    iconutil -c icns Maltex.iconset -o "${BUNDLE_PATH}/Contents/Resources/AppIcon.icns"
    rm -rf Maltex.iconset
    echo "✅ Icon integrated."
fi

# 7. Add PkgInfo
echo "APPL????" > "${BUNDLE_PATH}/Contents/PkgInfo"

# Ad-hoc Sign the whole app
echo "🔐 Signing ${APP_NAME}.app..."
codesign -s - --force --deep "${BUNDLE_PATH}"

echo "✨ DONE! ${APP_NAME}.app is ready."
