#!/bin/bash
set -euo pipefail

#==============================================================
# CaptureFlow — Mac App Store Build Pipeline
#==============================================================
#
# Usage:
#   ./scripts/build-mas.sh
#
# Required environment variables:
#   MAS_APP_IDENTITY       — "3rd Party Mac Developer Application: Name (TEAMID)"
#   MAS_INSTALLER_IDENTITY — "3rd Party Mac Developer Installer: Name (TEAMID)"
#
# Optional:
#   VERSION — override version string (default: 1.0.0)
#
#==============================================================

# --- Configuration ---
APP_NAME="CaptureFlow"
BUNDLE_ID="com.captureflow.app"
VERSION="${VERSION:-1.0.0}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$PROJECT_DIR/.build/dist-mas"
ENTITLEMENTS="$PROJECT_DIR/Distribution/CaptureFlow-MAS.entitlements"
INFO_PLIST="$PROJECT_DIR/Distribution/Info.plist"
ICON="$PROJECT_DIR/Distribution/AppIcon.icns"

# --- Validate ---
: "${MAS_APP_IDENTITY:?Set MAS_APP_IDENTITY to your 3rd Party Mac Developer Application identity}"
: "${MAS_INSTALLER_IDENTITY:?Set MAS_INSTALLER_IDENTITY to your 3rd Party Mac Developer Installer identity}"

echo "============================================"
echo "  $APP_NAME MAS Build Pipeline v$VERSION"
echo "============================================"
echo ""

# --- Step 1: Build with MAS flag ---
echo "==> [1/5] Building release binary (MAS)..."
swift build -c release --target "$APP_NAME" -Xswiftc -DMAS 2>&1

# Find the binary
BINARY=""
for candidate in \
    "$PROJECT_DIR/.build/release/$APP_NAME" \
    "$PROJECT_DIR/.build/arm64-apple-macosx/release/$APP_NAME"; do
    if [[ -f "$candidate" ]]; then
        BINARY="$candidate"
        break
    fi
done
[[ -n "$BINARY" ]] || { echo "ERROR: binary not found"; exit 1; }
echo "    Binary: $BINARY ($(du -h "$BINARY" | cut -f1))"

# --- Step 2: Assemble .app bundle ---
echo "==> [2/5] Assembling .app bundle..."
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR/$APP_NAME.app/Contents/MacOS"
mkdir -p "$DIST_DIR/$APP_NAME.app/Contents/Resources"

cp "$BINARY" "$DIST_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME"
cp "$INFO_PLIST" "$DIST_DIR/$APP_NAME.app/Contents/Info.plist"

# Inject version
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" \
    "$DIST_DIR/$APP_NAME.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" \
    "$DIST_DIR/$APP_NAME.app/Contents/Info.plist"

# Copy icon if it exists
if [[ -f "$ICON" ]]; then
    cp "$ICON" "$DIST_DIR/$APP_NAME.app/Contents/Resources/AppIcon.icns"
    echo "    Icon: included"
fi
echo "    Bundle: $DIST_DIR/$APP_NAME.app"

# --- Step 3: Sign .app bundle ---
echo "==> [3/5] Signing .app bundle (MAS)..."
codesign --deep --force \
    --sign "$MAS_APP_IDENTITY" \
    --entitlements "$ENTITLEMENTS" \
    --timestamp \
    "$DIST_DIR/$APP_NAME.app"

# --- Step 4: Verify signature ---
echo "==> [4/5] Verifying signature..."
codesign --verify --deep --strict "$DIST_DIR/$APP_NAME.app"
echo "    Signature valid"

# --- Step 5: Create .pkg for App Store ---
echo "==> [5/5] Creating .pkg..."
PKG_PATH="$DIST_DIR/$APP_NAME-$VERSION.pkg"
productbuild \
    --component "$DIST_DIR/$APP_NAME.app" /Applications \
    --sign "$MAS_INSTALLER_IDENTITY" \
    "$PKG_PATH"
echo "    PKG: $PKG_PATH ($(du -h "$PKG_PATH" | cut -f1))"

echo ""
echo "============================================"
echo "  MAS BUILD COMPLETE"
echo "  App:  $DIST_DIR/$APP_NAME.app"
echo "  PKG:  $PKG_PATH"
echo ""
echo "  Upload to App Store Connect:"
echo "    xcrun altool --upload-app -f \"$PKG_PATH\" \\"
echo "      --type macos --apiKey <KEY> --apiIssuer <ISSUER>"
echo "  Or use Transporter.app"
echo "============================================"
