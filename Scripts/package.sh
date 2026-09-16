#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build"
APP_NAME="Smurfbar"
APP_BUNDLE="$BUILD_DIR/${APP_NAME}.app"

echo "========================================"
echo "🚀 Packaging $APP_NAME for Release"
echo "========================================"

# 1. Build application bundle
"$SCRIPT_DIR/build.sh"

# Extract version from Info.plist
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$PROJECT_DIR/Resources/Info.plist" 2>/dev/null || echo "1.0.0")

DMG_VERSIONED="$BUILD_DIR/${APP_NAME}-v${VERSION}.dmg"
DMG_LATEST="$BUILD_DIR/${APP_NAME}.dmg"
ZIP_VERSIONED="$BUILD_DIR/${APP_NAME}-v${VERSION}.zip"
ZIP_LATEST="$BUILD_DIR/${APP_NAME}.zip"
CHECKSUMS_FILE="$BUILD_DIR/checksums.txt"

# 2. Build DMG using create_dmg.sh
"$SCRIPT_DIR/create_dmg.sh"

# 3. Build ZIP archive (preserves symlinks and resource forks)
echo ""
echo "📦 Creating ZIP archive..."
rm -f "$ZIP_VERSIONED" "$ZIP_LATEST"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_VERSIONED"
cp "$ZIP_VERSIONED" "$ZIP_LATEST"

echo "✅ ZIP created at: $ZIP_VERSIONED"
echo "   Size: $(ls -lh "$ZIP_VERSIONED" | awk '{print $5}')"

# 4. Generate SHA256 Checksums
echo ""
echo "🔒 Generating SHA256 checksums..."
rm -f "$CHECKSUMS_FILE"
cd "$BUILD_DIR"
shasum -a 256 "${APP_NAME}-v${VERSION}.dmg" >> "$CHECKSUMS_FILE"
shasum -a 256 "${APP_NAME}-v${VERSION}.zip" >> "$CHECKSUMS_FILE"
shasum -a 256 "${APP_NAME}.dmg" >> "$CHECKSUMS_FILE"
shasum -a 256 "${APP_NAME}.zip" >> "$CHECKSUMS_FILE"

echo "--- Checksums ---"
cat "$CHECKSUMS_FILE"
echo "-----------------"
echo "🎉 Release packaging complete!"
