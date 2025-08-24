#!/bin/bash

# Enhanced Flutter build script with automatic ShareExtension embedding
# Usage: ./flutter_build.sh [build_mode] [platform]
# Examples: 
#   ./flutter_build.sh debug ios
#   ./flutter_build.sh release ios
#   ./flutter_build.sh release ipa    # For Codemagic builds

set -e

# Default values
BUILD_MODE=${1:-debug}
PLATFORM=${2:-ios}

echo "🚀 Starting enhanced Flutter build..."
echo "📋 Mode: $BUILD_MODE"
echo "📋 Platform: $PLATFORM"

# Run Flutter build
echo "🔨 Running Flutter build..."
if [ "$PLATFORM" = "ipa" ]; then
    # Special case for Codemagic IPA builds
    # Note: Export options are now handled directly in codemagic.yaml
    flutter build ipa --release
    PLATFORM="ios"
    BUILD_MODE="release"
elif [ "$BUILD_MODE" = "release" ]; then
    flutter build $PLATFORM --release
else
    flutter build $PLATFORM --debug
fi

# Check if this is an iOS build
if [ "$PLATFORM" = "ios" ]; then
    echo "📱 iOS build detected - checking ShareExtension embedding..."
    
    # Define paths
    if [ "$BUILD_MODE" = "release" ]; then
        CONFIGURATION="Release"
    else
        CONFIGURATION="Debug"
    fi
    
    BUILT_PRODUCTS_DIR="build/ios/$CONFIGURATION-iphoneos"
    APP_PATH="$BUILT_PRODUCTS_DIR/Runner.app"
    PLUGINS_DIR="$APP_PATH/PlugIns"
    SHARE_EXTENSION_SOURCE="$BUILT_PRODUCTS_DIR/ShareExtension.appex"
    SHARE_EXTENSION_DEST="$PLUGINS_DIR/ShareExtension.appex"
    
    # Check if app was built
    if [ -d "$APP_PATH" ]; then
        echo "✅ App bundle found at: $APP_PATH"
        
        # Check if ShareExtension was built
        if [ -d "$SHARE_EXTENSION_SOURCE" ]; then
            echo "✅ ShareExtension found at: $SHARE_EXTENSION_SOURCE"
            
            # Create PlugIns directory if needed
            mkdir -p "$PLUGINS_DIR"
            
            # Remove existing ShareExtension if present
            if [ -d "$SHARE_EXTENSION_DEST" ]; then
                rm -rf "$SHARE_EXTENSION_DEST"
            fi
            
            # Copy ShareExtension
            echo "📋 Embedding ShareExtension..."
            cp -R "$SHARE_EXTENSION_SOURCE" "$SHARE_EXTENSION_DEST"
            
            if [ -d "$SHARE_EXTENSION_DEST" ]; then
                echo "✅ ShareExtension successfully embedded!"
                echo "📁 Location: $SHARE_EXTENSION_DEST"
            else
                echo "❌ Failed to embed ShareExtension"
                exit 1
            fi
        else
            echo "⚠️  ShareExtension not found at: $SHARE_EXTENSION_SOURCE"
            echo "   This is normal if ShareExtension target wasn't built."
        fi
    else
        echo "❌ App bundle not found at: $APP_PATH"
        echo "   Flutter build may have failed."
        exit 1
    fi
fi

echo "🎉 Enhanced Flutter build completed successfully!"

# Optional: Show build output location
if [ "$PLATFORM" = "ios" ]; then
    if [ "$BUILD_MODE" = "release" ]; then
        echo "📦 Build output: build/ios/Release-iphoneos/Runner.app"
    else
        echo "📦 Build output: build/ios/Debug-iphoneos/Runner.app"
    fi
fi
