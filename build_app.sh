#!/bin/bash
#
# Build script for PG_BT4 Bridge menu bar application
# Creates a proper .app bundle that can be dragged to Applications folder
#

set -e

echo "🎸 Building PG_BT4 Bridge Menu Bar App..."

# Build release version
echo "📦 Building release binary..."
swift build -c release --product bt4bridge-app

# Create app bundle structure
APP_NAME="PG BT4 Bridge.app"
BUILD_DIR=".build/release"
APP_DIR="$BUILD_DIR/$APP_NAME"

echo "📁 Creating app bundle structure..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy executable
echo "📋 Copying executable..."
cp "$BUILD_DIR/bt4bridge-app" "$APP_DIR/Contents/MacOS/PG BT4 Bridge"
chmod +x "$APP_DIR/Contents/MacOS/PG BT4 Bridge"

# Copy resources bundle (if it exists)
BUNDLE_DIR="$BUILD_DIR/bt4bridge_bt4bridge-app.bundle"
if [ -d "$BUNDLE_DIR" ]; then
    echo "📦 Copying resources bundle..."
    cp -r "$BUNDLE_DIR" "$APP_DIR/Contents/Resources/"
fi

# Copy app icon (if it exists)
ICON_FILE="Sources/bt4bridge-app/Resources/AppIcon.icns"
if [ -f "$ICON_FILE" ]; then
    echo "🎨 Copying app icon..."
    cp "$ICON_FILE" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

# Create Info.plist
echo "📝 Creating Info.plist..."
cat > "$APP_DIR/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>PG BT4 Bridge</string>
    <key>CFBundleIdentifier</key>
    <string>com.bt4bridge.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>PG BT4 Bridge</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>PG BT4 Bridge needs Bluetooth access to connect to your PG_BT4 foot controller.</string>
    <key>NSBluetoothPeripheralUsageDescription</key>
    <string>PG BT4 Bridge needs Bluetooth access to connect to your PG_BT4 foot controller.</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024. All rights reserved.</string>
</dict>
</plist>
EOF

echo "✅ Build complete!"
echo ""
echo "📍 App bundle location: $APP_DIR"
echo ""
echo "To install:"
echo "  cp -r '$APP_DIR' /Applications/"
echo ""
echo "To run:"
echo "  open '$APP_DIR'"
echo ""
