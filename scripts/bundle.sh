#!/bin/bash
# Creates an InfisicalMenu.app bundle from the swift build output
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build/debug"
APP_DIR="$PROJECT_DIR/build/InfisicalMenu.app"

# Clean previous bundle
rm -rf "$APP_DIR"

# Create app bundle structure
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/InfisicalMenu" "$APP_DIR/Contents/MacOS/InfisicalMenu"

# Copy Info.plist
cp "$PROJECT_DIR/InfisicalMenu/Info.plist" "$APP_DIR/Contents/Info.plist"

# Copy resource bundle if present
if [ -d "$BUILD_DIR/InfisicalMenu_InfisicalMenu.bundle" ]; then
    cp -R "$BUILD_DIR/InfisicalMenu_InfisicalMenu.bundle" "$APP_DIR/Contents/Resources/"
fi

echo "App bundle created at: $APP_DIR"
echo "Run with: open $APP_DIR"
