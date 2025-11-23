# Google Play App Signing - Critical for Production

## The Problem

If your app is published on Google Play Store, Google Play **re-signs your app** with their own key. This means:

- Your upload keystore SHA-1: `82:9E:BA:9F:78:B0:A5:F2:76:7B:78:87:07:DF:12:C4:6F:DC:45:A8`
- **Won't match** the actual signing key used by Google Play
- Google Sign In will fail with `ApiException: 10` (DEVELOPER_ERROR)

## How to Get Google Play App Signing Key SHA Fingerprints

1. **Go to Google Play Console:**
   - https://play.google.com/console
   - Sign in with your developer account

2. **Navigate to your app:**
   - Select "RecipEase" (or your app name)
   - Go to **Setup** → **App Integrity** (or **Release** → **Setup** → **App Integrity**)

3. **Find the App Signing Key Certificate:**
   - Look for "App signing key certificate" section
   - You'll see SHA-1 and SHA-256 fingerprints
   - **These are the fingerprints you need!**

4. **Add to Firebase:**
   - Go to Firebase Console: https://console.firebase.google.com/
   - Select project: **recipe-app-c2fcc**
   - Go to **Project Settings** (gear icon)
   - Select your Android app: **com.recipease.kitchen**
   - Scroll to **SHA certificate fingerprints**
   - Click **Add fingerprint**
   - Add the **SHA-1** from Google Play Console
   - Add the **SHA-256** from Google Play Console
   - Wait 5-10 minutes for changes to propagate

## Important Notes

- If Google Play App Signing is enabled, you **MUST** use the Google Play signing key SHA fingerprints
- The upload keystore SHA fingerprints are only used if you're distributing APKs directly (not through Play Store)
- You can have multiple SHA fingerprints registered in Firebase (both upload and Play signing keys)

## Verify Google Play App Signing Status

To check if Google Play App Signing is enabled:
1. Go to Google Play Console
2. Select your app
3. Go to **Setup** → **App Integrity**
4. Look for "App signing by Google Play" - if it says "Enabled", you need to use those SHA fingerprints

## After Adding Fingerprints

1. Wait 5-10 minutes for Firebase to propagate changes
2. Users may need to update the app (if it's already installed)
3. Test Google Sign In in a production build

