#!/bin/bash

# Post-build script to embed ShareExtension in Runner.app
# This script ensures the ShareExtension.appex is properly copied to the app bundle

set -e

echo "🔧 Starting ShareExtension embedding process..."

# Configuration
CONFIGURATION=${CONFIGURATION:-Debug}
PLATFORM_NAME=${PLATFORM_NAME:-iphoneos}
BUILT_PRODUCTS_DIR=${BUILT_PRODUCTS_DIR:-"$PWD/build/ios/$CONFIGURATION-$PLATFORM_NAME"}
TARGET_BUILD_DIR=${TARGET_BUILD_DIR:-"$BUILT_PRODUCTS_DIR"}
WRAPPER_NAME=${WRAPPER_NAME:-"Runner.app"}
SHARE_EXTENSION_NAME="ShareExtension.appex"

# Paths
APP_PATH="$TARGET_BUILD_DIR/$WRAPPER_NAME"
PLUGINS_DIR="$APP_PATH/PlugIns"
SHARE_EXTENSION_SOURCE="$BUILT_PRODUCTS_DIR/$SHARE_EXTENSION_NAME"
SHARE_EXTENSION_DEST="$PLUGINS_DIR/$SHARE_EXTENSION_NAME"

echo "📁 App path: $APP_PATH"
echo "📁 ShareExtension source: $SHARE_EXTENSION_SOURCE"
echo "📁 ShareExtension destination: $SHARE_EXTENSION_DEST"

# Check if app bundle exists
if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: App bundle not found at $APP_PATH"
    exit 1
fi

# Check if ShareExtension was built
if [ ! -d "$SHARE_EXTENSION_SOURCE" ]; then
    echo "❌ Error: ShareExtension not found at $SHARE_EXTENSION_SOURCE"
    echo "   Make sure ShareExtension target is being built."
    exit 1
fi

# Create PlugIns directory if it doesn't exist
if [ ! -d "$PLUGINS_DIR" ]; then
    echo "📁 Creating PlugIns directory..."
    mkdir -p "$PLUGINS_DIR"
fi

# Remove existing ShareExtension if present
if [ -d "$SHARE_EXTENSION_DEST" ]; then
    echo "🗑️  Removing existing ShareExtension..."
    rm -rf "$SHARE_EXTENSION_DEST"
fi

# Copy ShareExtension to app bundle
echo "📋 Copying ShareExtension to app bundle..."
cp -R "$SHARE_EXTENSION_SOURCE" "$SHARE_EXTENSION_DEST"

# Verify the copy was successful
if [ -d "$SHARE_EXTENSION_DEST" ]; then
    echo "✅ ShareExtension successfully embedded in app bundle"
    echo "📁 ShareExtension location: $SHARE_EXTENSION_DEST"
    
    # List contents to verify
    echo "📋 ShareExtension contents:"
    ls -la "$SHARE_EXTENSION_DEST"
else
    echo "❌ Error: Failed to embed ShareExtension"
    exit 1
fi

echo "🎉 ShareExtension embedding completed successfully!"
