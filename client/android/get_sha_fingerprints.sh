#!/bin/bash

# Script to get SHA-1 and SHA-256 fingerprints for Android app
# These need to be added to Firebase Console -> Project Settings -> Your App -> SHA certificate fingerprints

echo "=========================================="
echo "Android App SHA Fingerprints"
echo "=========================================="
echo ""

# Debug keystore (default Android debug keystore)
echo "📱 DEBUG KEYSTORE (for development/testing):"
echo "--------------------------------------------"
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android 2>/dev/null | grep -E "(SHA1|SHA256)" | sed 's/^[[:space:]]*/  /'
echo ""

# Release keystore (for production)
if [ -f "upload-keystore.jks" ]; then
    echo "📱 RELEASE KEYSTORE (for production):"
    echo "--------------------------------------------"
    # Read passwords from key.properties if it exists
    if [ -f "key.properties" ]; then
        STORE_PASS=$(grep "storePassword=" key.properties | cut -d'=' -f2)
        KEY_PASS=$(grep "keyPassword=" key.properties | cut -d'=' -f2)
        KEY_ALIAS=$(grep "keyAlias=" key.properties | cut -d'=' -f2)
        
        if [ ! -z "$STORE_PASS" ] && [ ! -z "$KEY_PASS" ] && [ ! -z "$KEY_ALIAS" ]; then
            keytool -list -v -keystore upload-keystore.jks -alias "$KEY_ALIAS" -storepass "$STORE_PASS" -keypass "$KEY_PASS" 2>/dev/null | grep -E "(SHA1|SHA256)" | sed 's/^[[:space:]]*/  /'
        else
            echo "  ⚠️  Could not read passwords from key.properties"
        fi
    else
        echo "  ⚠️  key.properties not found. Please run manually:"
        echo "  keytool -list -v -keystore upload-keystore.jks -alias upload"
    fi
else
    echo "⚠️  Release keystore (upload-keystore.jks) not found"
fi

echo ""
echo "=========================================="
echo "📋 INSTRUCTIONS:"
echo "=========================================="
echo "1. Copy the SHA-1 and SHA-256 fingerprints above"
echo "2. Go to Firebase Console: https://console.firebase.google.com/"
echo "3. Select your project: recipe-app-c2fcc"
echo "4. Go to Project Settings (gear icon)"
echo "5. Select your Android app: com.recipease.kitchen"
echo "6. Scroll to 'SHA certificate fingerprints' section"
echo "7. Click 'Add fingerprint' and paste each SHA-1 and SHA-256"
echo "8. Make sure to add BOTH debug and release fingerprints"
echo "9. After adding, wait a few minutes and try Google Sign In again"
echo ""

