# iOS ShareExtension Setup & Troubleshooting

This document explains the iOS ShareExtension configuration for RecipEase and how to resolve common issues.

## Overview

The RecipEase app includes a ShareExtension that allows users to share recipe URLs from Safari and other apps directly into the RecipEase app for import.

## Architecture

```
RecipEase.app/
├── Runner.app (Main App)
└── PlugIns/
    └── ShareExtension.appex (Share Extension)
```

## Automated Build Solutions

### 1. Enhanced Flutter Build Script (Recommended)

Use the enhanced Flutter build script that automatically embeds the ShareExtension:

```bash
# From project root
cd client
./flutter_build.sh debug ios    # For debug builds
./flutter_build.sh release ios  # For release builds
```

### 2. Make Commands (Easiest)

Use the provided Makefile commands:

```bash
# From project root
make ios-debug     # Build debug with ShareExtension
make ios-release   # Build release with ShareExtension  
make ios-ipa       # Build IPA for distribution (Codemagic compatible)
make run-ios       # Build and run on device/simulator
make clean         # Clean all artifacts
make help          # Show all commands
```

### 3. Codemagic CI/CD Integration

The `codemagic.yaml` is configured to use the enhanced build script:

```yaml
# Build the iOS IPA with automatic ShareExtension embedding
- name: Build iOS IPA with ShareExtension
  script: cd client && ./flutter_build.sh release ipa
```

This ensures your distributed apps always include the properly embedded ShareExtension.

### 4. Manual Embedding

If automatic embedding fails, manually embed the ShareExtension:

```bash
cd client
flutter build ios --debug
./ios/scripts/embed_share_extension.sh
```

## Xcode Integration

The project includes an automated Xcode build phase that runs after the "Embed Foundation Extensions" phase. This ensures the ShareExtension is embedded even when building directly from Xcode.

## Verification

After building, verify the ShareExtension is properly embedded:

```bash
ls -la build/ios/Debug-iphoneos/Runner.app/PlugIns/
# Should show: ShareExtension.appex
```

## Testing Share Functionality

1. Install the app on a device or simulator
2. Open Safari and navigate to any recipe website
3. Tap the Share button
4. Look for "RecipEase" in the share options
5. Tap it to import the recipe

## Troubleshooting

### ShareExtension Not Appearing in Share Sheet

**Symptoms:** RecipEase doesn't appear as an option when sharing from Safari

**Causes & Solutions:**

1. **ShareExtension not embedded:**
   ```bash
   # Check if embedded
   ls -la build/ios/Debug-iphoneos/Runner.app/PlugIns/
   
   # If missing, manually embed
   ./ios/scripts/embed_share_extension.sh
   ```

2. **App not properly installed:**
   ```bash
   # Reinstall the app
   flutter install
   ```

3. **iOS cache issues:**
   - Restart the device/simulator
   - Delete and reinstall the app

### Build Errors

**ShareExtension fails to build:**

1. **Code signing issues:**
   - Ensure you have a valid Apple Developer account added to Xcode
   - Check that automatic signing is enabled for both Runner and ShareExtension targets

2. **Missing dependencies:**
   ```bash
   cd ios
   pod install
   pod update
   ```

### Flutter Build Doesn't Include ShareExtension

**Symptoms:** Flutter builds successfully but ShareExtension is missing from app bundle

**Solution:** Use the automated build scripts instead of direct `flutter build` commands:

```bash
# Instead of: flutter build ios --debug
# Use:
./flutter_build.sh debug ios

# Or:
make ios-debug
```

## Configuration Files

### Key Files:
- `ios/ShareExtension/Info.plist` - ShareExtension configuration
- `ios/ShareExtension/ShareExtension.entitlements` - App group entitlements  
- `ios/Runner/Info.plist` - Main app configuration with share handler setup
- `ios/scripts/embed_share_extension.sh` - Automated embedding script
- `flutter_build.sh` - Enhanced Flutter build script

### Important Settings:

1. **App Group ID:** `group.com.recipease.kitchen`
   - Must match in both main app and ShareExtension entitlements

2. **Bundle Identifiers:**
   - Main app: `com.recipease.kitchen`
   - ShareExtension: `com.recipease.kitchen.ShareExtension`

3. **Supported Content Types:**
   - `public.url` - Web URLs
   - `public.text` - Text content
   - `public.image` - Images

## Development Workflow

### Daily Development:
```bash
make ios-debug && flutter install
```

### Testing Share Functionality:
```bash
make ios-debug
# Test in Safari -> Share -> RecipEase
```

### Release Builds:
```bash
make ios-release
```

### Clean Build:
```bash
make clean
make ios-debug
```

## Support

If you encounter issues:

1. Check that all automated scripts are executable:
   ```bash
   chmod +x flutter_build.sh
   chmod +x ios/scripts/embed_share_extension.sh
   ```

2. Verify Xcode project integrity:
   ```bash
   cd ios
   xcodebuild -list
   # Should show ShareExtension in targets
   ```

3. Check Flutter doctor:
   ```bash
   flutter doctor -v
   ```

## Notes

- The ShareExtension is automatically built when building the main app
- Manual embedding is only needed if the automatic process fails
- The ShareExtension requires iOS 12.0+ (same as main app)
- Share functionality only works on physical devices and simulators, not in Flutter desktop modes
