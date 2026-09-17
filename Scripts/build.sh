#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build"
APP_NAME="Smurfbar"
APP_BUNDLE="$BUILD_DIR/${APP_NAME}.app"

echo "🔨 Building Smurfbar..."
cd "$PROJECT_DIR"

# Build with Swift Package Manager
swift build -c release 2>&1

EXECUTABLE="$BUILD_DIR/release/${APP_NAME}"

if [ ! -f "$EXECUTABLE" ]; then
    echo "❌ Build failed — executable not found at $EXECUTABLE"
    exit 1
fi

echo "📦 Creating app bundle..."

# Create .app bundle structure
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"

# Copy Info.plist
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# If there's an icon set, copy it
if [ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi
if [ -f "$PROJECT_DIR/Resources/AppIcon.png" ]; then
    cp "$PROJECT_DIR/Resources/AppIcon.png" "$APP_BUNDLE/Contents/Resources/AppIcon.png"
fi

# Copy any SPM resource bundles
find "$BUILD_DIR" -name "*.bundle" -maxdepth 4 -exec cp -R {} "$APP_BUNDLE/Contents/Resources/" \; 2>/dev/null || true

# Sign the app bundle so macOS TCC recognizes its bundle identifier and Info.plist
echo "🔏 Signing app bundle..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "✅ App bundle created at: $APP_BUNDLE"
echo ""
echo "To run:"
echo "  open $APP_BUNDLE"
echo ""
echo "To install to /Applications:"
echo "  cp -R $APP_BUNDLE /Applications/"
