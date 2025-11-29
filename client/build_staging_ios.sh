#!/bin/bash

# Build script for creating a staging iOS build for TestFlight
# Usage: ./build_staging_ios.sh

set -e  # Exit on error

echo "🚀 Building staging iOS app for TestFlight..."
echo ""

# Navigate to client directory
cd "$(dirname "$0")"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build iOS archive with staging environment
echo "🔨 Building iOS archive (staging environment)..."
flutter build ipa \
  --release \
  --dart-define=ENV=staging \
  --export-options-plist=ios/export_options.plist

echo ""
echo "✅ Build complete!"
echo ""
echo "📱 Next steps:"
echo "1. Open Xcode: open ios/Runner.xcworkspace"
echo "2. Product > Archive (or use the archive you just created)"
echo "3. In Organizer, click 'Distribute App'"
echo "4. Select 'App Store Connect'"
echo "5. Follow the prompts to upload to TestFlight"
echo ""
echo "Or use Transporter app:"
echo "1. The .ipa file is located at: build/ios/ipa/*.ipa"
echo "2. Open Transporter app"
echo "3. Drag and drop the .ipa file"
echo "4. Click 'Deliver'"
echo ""
echo "🌐 Staging API URL: https://flutter-recipe-app-826154873845.us-west2.run.app/api"

