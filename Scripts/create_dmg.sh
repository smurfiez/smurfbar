#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build"
APP_NAME="Smurfbar"
APP_BUNDLE="$BUILD_DIR/${APP_NAME}.app"

# Ensure app is built
if [ ! -d "$APP_BUNDLE" ] || [ "${1:-}" = "--rebuild" ]; then
    echo "🔨 Building application bundle first..."
    "$SCRIPT_DIR/build.sh"
fi

# Extract version from Info.plist
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$PROJECT_DIR/Resources/Info.plist" 2>/dev/null || echo "1.0.0")
DMG_NAME="${APP_NAME}-v${VERSION}.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"
LATEST_DMG_PATH="$BUILD_DIR/${APP_NAME}.dmg"
STAGING_DIR="$BUILD_DIR/dmg-staging"

echo "💿 Packaging $APP_NAME v$VERSION into DMG..."

# Clean up previous staging and dmg
rm -rf "$STAGING_DIR" "$DMG_PATH" "$LATEST_DMG_PATH"
mkdir -p "$STAGING_DIR"

# Copy App Bundle to staging
cp -R "$APP_BUNDLE" "$STAGING_DIR/"

# Create Applications symlink for drag-and-drop install
ln -s /Applications "$STAGING_DIR/Applications"

# Create DMG with hdiutil
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

# Clean up staging directory
rm -rf "$STAGING_DIR"

# Also create generic Smurfbar.dmg copy for direct link convenience
cp "$DMG_PATH" "$LATEST_DMG_PATH"

echo ""
echo "✅ DMG created successfully!"
echo "   File: $DMG_PATH"
echo "   Size: $(ls -lh "$DMG_PATH" | awk '{print $5}')"
echo "   SHA256: $(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
echo "   Also copied to: $LATEST_DMG_PATH"
