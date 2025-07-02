# iOS Configuration Guide for Recipease App

This guide provides a comprehensive overview of the iOS configuration for the Recipease Flutter app, including all necessary settings, permissions, and platform-specific configurations.

## Overview

The Recipease app is a Flutter application that has been configured to work on iOS with the following key features:

- Firebase Authentication (Email/Password and Google Sign-In)
- Google Mobile Ads integration
- In-App Purchases
- Share functionality
- File picker and camera access
- Push notifications
- Background processing

## Bundle Identifier

**Current Bundle ID**: `com.recipease.kitchen`

This bundle identifier is used consistently across:

- Xcode project configuration
- Firebase iOS app configuration
- Google Sign-In configuration
- App Store Connect (when publishing)

## Key Configuration Files

### 1. Info.plist (`ios/Runner/Info.plist`)

The main iOS configuration file contains:

#### App Information

- **Display Name**: "Recipease"
- **Bundle Name**: "recipease"
- **Bundle Identifier**: `$(PRODUCT_BUNDLE_IDENTIFIER)` (resolves to `com.recipease.kitchen`)

#### Permissions

- **Photo Library**: For uploading profile pictures and saving recipe images
- **Camera**: For taking profile pictures and capturing recipe photos
- **Microphone**: For video recording and voice notes
- **Location**: For location-based recipe recommendations (optional)

#### URL Schemes

- **Google Sign-In**: `com.googleusercontent.apps.826154873845-4904phdrsiv04juljvs6n2reirpje1qg`
- **Share Extension**: `recipease`

#### Google Mobile Ads

- **App ID**: `ca-app-pub-9981622851892833~1458002511`
- **SKAdNetwork Identifiers**: Comprehensive list for ad attribution

#### App Transport Security

- Secure HTTPS connections only
- Exceptions for Firebase and Google APIs with TLS 1.2+ requirement

#### Background Modes

- Background fetch
- Remote notifications

### 2. Firebase Configuration (`lib/firebase_options.dart`)

iOS-specific Firebase settings:

```dart
static const FirebaseOptions ios = FirebaseOptions(
  apiKey: 'AIzaSyDGJ4Ds_DsWNb_zPWIeJXyOVW6RyOxb3i0',
  appId: '1:826154873845:ios:a9a2ed9cc06ecc595be6bc',
  messagingSenderId: '826154873845',
  projectId: 'recipe-app-c2fcc',
  databaseURL: 'https://recipe-app-c2fcc-default-rtdb.firebaseio.com',
  storageBucket: 'recipe-app-c2fcc.appspot.com',
  androidClientId: '826154873845-2uber91hjcgap6qr688uo3lqeim47mjj.apps.googleusercontent.com',
  iosClientId: '826154873845-4904phdrsiv04juljvs6n2reirpje1qg.apps.googleusercontent.com',
  iosBundleId: 'com.recipease.kitchen',
);
```

### 3. Xcode Project Configuration (`ios/Runner.xcodeproj/project.pbxproj`)

- **Deployment Target**: iOS 12.0+
- **Swift Version**: 5.0
- **Bundle Identifier**: `com.recipease.kitchen`
- **Code Signing**: Automatic (for development)

## Required Setup Steps

### 1. Firebase Console Configuration

1. **Create iOS App in Firebase Console**:

   - Go to Firebase Console → Project Settings → Your Apps
   - Add iOS app with bundle ID: `com.recipease.kitchen`
   - Download `GoogleService-Info.plist` and add to Xcode project

2. **Enable Authentication Methods**:

   - Email/Password authentication
   - Google Sign-In (configure OAuth client)

3. **Configure Firestore Rules**:
   - Set up appropriate security rules for user data

### 2. Google Sign-In Configuration

1. **Google Cloud Console**:

   - Create OAuth 2.0 client ID for iOS
   - Bundle ID: `com.recipease.kitchen`
   - Add URL scheme to Info.plist

2. **Firebase Console**:
   - Add the OAuth client ID to Firebase project settings

### 3. Google Mobile Ads Setup

1. **AdMob Console**:

   - Create iOS app with bundle ID: `com.recipease.kitchen`
   - Get App ID: `ca-app-pub-9981622851892833~1458002511`
   - Create ad units for banner ads

2. **Test Configuration**:
   - Use test ad unit IDs during development
   - Switch to production IDs for release

### 4. In-App Purchase Configuration

1. **App Store Connect**:

   - Create in-app purchase products:
     - `recipease_premium_monthly`
     - `recipease_premium_yearly`
     - `recipease_premium_lifetime`
   - Configure pricing and availability

2. **Sandbox Testing**:
   - Create sandbox test accounts
   - Test purchase flow in development

### 5. App Store Connect Setup

1. **App Information**:

   - App name: "Recipease"
   - Bundle ID: `com.recipease.kitchen`
   - Category: Food & Drink

2. **Screenshots and Metadata**:

   - Prepare screenshots for different device sizes
   - Write app description and keywords

3. **Privacy Policy**:
   - Required for apps with user accounts and data collection

## Development Setup

### Prerequisites

1. **Xcode**: Latest version (15.0+ recommended)
2. **iOS Simulator**: For testing on different device types
3. **Physical Device**: For testing camera, location, and push notifications
4. **Apple Developer Account**: For code signing and App Store distribution

### Build Configuration

1. **Debug Configuration**:

   ```bash
   flutter build ios --debug
   ```

2. **Release Configuration**:

   ```bash
   flutter build ios --release
   ```

3. **Archive for App Store**:
   - Use Xcode to create archive
   - Upload to App Store Connect

### Testing Checklist

- [ ] App launches successfully
- [ ] Firebase authentication works (email/password)
- [ ] Google Sign-In works
- [ ] Camera and photo library access
- [ ] Push notifications (if implemented)
- [ ] In-app purchases (sandbox testing)
- [ ] Google Mobile Ads display correctly
- [ ] Share functionality works
- [ ] Background processing
- [ ] Network connectivity
- [ ] App state management (background/foreground)

## Common Issues and Solutions

### 1. Google Sign-In Issues

**Problem**: Sign-in fails with "Sign in aborted" error
**Solution**:

- Verify OAuth client ID in Firebase console
- Check URL scheme in Info.plist
- Ensure bundle ID matches in all configurations

### 2. Firebase Configuration Issues

**Problem**: Firebase services not working
**Solution**:

- Verify `GoogleService-Info.plist` is added to Xcode project
- Check bundle ID matches in Firebase console
- Ensure Firebase initialization in `main.dart`

### 3. Ad Display Issues

**Problem**: Ads not showing
**Solution**:

- Verify AdMob App ID in Info.plist
- Check ad unit IDs in `ad_helper.dart`
- Test with test ad unit IDs first

### 4. Permission Issues

**Problem**: Camera/photo library access denied
**Solution**:

- Check permission descriptions in Info.plist
- Request permissions at appropriate times
- Handle permission denial gracefully

### 5. Build Issues

**Problem**: Build fails with signing errors
**Solution**:

- Check code signing settings in Xcode
- Verify Apple Developer account setup
- Use automatic code signing for development

## Security Considerations

1. **API Keys**: Never commit sensitive keys to version control
2. **Firebase Rules**: Implement proper security rules
3. **Data Privacy**: Follow Apple's privacy guidelines
4. **Network Security**: Use HTTPS for all network requests
5. **App Transport Security**: Configure ATS properly

## Performance Optimization

1. **Image Optimization**: Use appropriate image formats and sizes
2. **Memory Management**: Monitor memory usage in Instruments
3. **Network Requests**: Implement proper caching and error handling
4. **Background Processing**: Minimize background activity

## Deployment Checklist

### Pre-Release

- [ ] Test on multiple iOS devices and versions
- [ ] Verify all features work correctly
- [ ] Check app performance and memory usage
- [ ] Test in-app purchases with sandbox accounts
- [ ] Verify ad integration
- [ ] Test push notifications
- [ ] Review privacy policy and terms of service

### App Store Submission

- [ ] Create app record in App Store Connect
- [ ] Upload app binary
- [ ] Add screenshots and metadata
- [ ] Configure app pricing and availability
- [ ] Submit for review

### Post-Release

- [ ] Monitor crash reports and analytics
- [ ] Respond to user reviews
- [ ] Plan updates and improvements
- [ ] Monitor ad performance and revenue

## Additional Resources

- [Flutter iOS Deployment](https://docs.flutter.dev/deployment/ios)
- [Firebase iOS Setup](https://firebase.google.com/docs/ios/setup)
- [Google Sign-In iOS](https://developers.google.com/identity/sign-in/ios)
- [Google Mobile Ads iOS](https://developers.google.com/admob/ios/quick-start)
- [Apple Developer Documentation](https://developer.apple.com/documentation/)

## Support

For issues specific to iOS configuration:

1. Check Flutter and plugin documentation
2. Review Apple Developer documentation
3. Test on physical devices when possible
4. Use Xcode debugging tools for troubleshooting

---

**Last Updated**: January 2025
**Flutter Version**: 3.7.0+
**iOS Deployment Target**: 12.0+
**Xcode Version**: 15.0+
