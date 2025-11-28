import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../services/api_client.dart';
import '../services/collection_service.dart';
import '../services/credits_service.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // For iOS, use explicit client ID
    // For Android, don't specify clientId - it will be auto-detected from google-services.json
    clientId:
        defaultTargetPlatform == TargetPlatform.iOS
            ? '826154873845-9n1vqk797jnrvarkd3stsehjhl6ff1le.apps.googleusercontent.com'
            : null,
    scopes: ['email', 'profile'],
  );
  final ApiClient _apiClient = ApiClient();
  final CollectionService _collectionService = CollectionService();
  final CreditsService _creditsService = CreditsService();

  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      _error = null;
      notifyListeners();
    });
    
    // Listen for FCM token refresh and update Firestore
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      if (_user != null) {
        _updateFcmToken(newToken);
      }
    });
  }
  
  /// Updates the FCM token in Firestore for push notifications
  Future<void> _updateFcmToken([String? token]) async {
    try {
      if (_user == null) return;
      
      // Get current FCM token if not provided
      final fcmToken = token ?? await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) {
        if (kDebugMode) {
          debugPrint('⚠️ FCM token is null, skipping update');
        }
        return;
      }
      
      // Update token in Firestore
      await _firestore.collection('users').doc(_user!.uid).update({
        'fcmToken': fcmToken,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      
      if (kDebugMode) {
        debugPrint('✅ FCM token updated for user ${_user!.uid}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Error updating FCM token: $e');
      }
      // Don't rethrow - FCM token update failure shouldn't break login flow
    }
  }

  // Helper method to create/update user profile in Firestore
  Future<void> _createOrUpdateUserProfile(
    User user, {
    String? displayName,
  }) async {
    try {
      final userDoc = _firestore.collection('users').doc(user.uid);
      final userData = {
        'email': user.email,
        'displayName': displayName ?? user.displayName,
        'photoURL': user.photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Check if document exists
      final docSnapshot = await userDoc.get();
      final isNewUser = !docSnapshot.exists;

      if (isNewUser) {
        // If document doesn't exist, add createdAt
        userData['createdAt'] = FieldValue.serverTimestamp();
      }

      // Update or create the document
      await userDoc.set(userData, SetOptions(merge: true));

      // If this is a new user, create default collections and grant welcome credits
      if (isNewUser) {
        try {
          await _collectionService.createDefaultCollections();
        } catch (e) {
          // Don't fail the registration if collections creation fails
          if (kDebugMode) {
            debugPrint('Error creating default collections: $e');
          }
        }

        // Grant welcome credits to new users
        try {
          await _creditsService.addCredits(
            recipeImports: 5,
            recipeGenerations: 5,
            reason: '🎁 Welcome bonus - 10 free credits to get you started!',
          );
          if (kDebugMode) {
            debugPrint('✅ Welcome credits granted: 5 imports + 5 generations');
          }
        } catch (e) {
          // Don't fail the registration if credit grant fails
          if (kDebugMode) {
            debugPrint('Error granting welcome credits: $e');
          }
        }
      }
      
      // Update FCM token for push notifications
      await _updateFcmToken();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error creating/updating user profile: $e');
      }
      rethrow;
    }
  }

  // Sign in with email and password
  Future<User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Configure auth persistence based on platform
      if (kIsWeb) {
        await _auth.setPersistence(Persistence.LOCAL);
      }

      // Attempt sign in with platform-specific configuration
      UserCredential userCredential;
      if (kIsWeb) {
        // Web platform requires reCAPTCHA
        userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        // Mobile platforms don't require reCAPTCHA
        userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      _user = userCredential.user;

      // Update user profile in Firestore
      if (_user != null) {
        await _createOrUpdateUserProfile(_user!);

        // Force refresh ID token to ensure currentUser is properly set
        // This prevents race conditions when making API calls immediately after login
        await _user!.getIdToken(true);

        // Add a delay to ensure Firebase Auth state is fully propagated
        // This is crucial for preventing "User not authenticated" errors
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      return _user;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          _error = 'No account found with this email. Please sign up first.';
          break;
        case 'wrong-password':
          _error = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          _error = 'Please enter a valid email address.';
          break;
        case 'user-disabled':
          _error = 'This account has been disabled. Please contact support.';
          break;
        case 'invalid-credential':
          _error = 'Invalid email or password. Please try again.';
          break;
        case 'network-request-failed':
          _error = 'Network error. Please check your internet connection.';
          break;
        default:
          _error = 'An error occurred during sign in. Please try again.';
      }
      return null;
    } catch (e) {
      _error = 'An unexpected error occurred. Please try again.';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Register with email and password
  Future<void> registerWithEmailAndPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Only set persistence on web platforms
      if (kIsWeb) {
        await _auth.setPersistence(Persistence.LOCAL);
      }

      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await result.user!.updateDisplayName(displayName);
      _user = result.user;

      // Create user profile in Firestore
      if (_user != null) {
        await _createOrUpdateUserProfile(_user!, displayName: displayName);
        await _user!.getIdToken(true);
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') {
        _error = 'Please check your internet connection and try again.';
      } else if (e.code == 'email-already-in-use') {
        _error = 'The email address is already in use by another account.';
      } else {
        _error = e.message ?? 'An error occurred during registration.';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('🔐 [GOOGLE SIGN IN] Starting Google Sign In...');
      debugPrint('🔐 [GOOGLE SIGN IN] Platform: $defaultTargetPlatform');

      // Ensure we're signed out first to avoid cached state issues
      debugPrint(
        '🔐 [GOOGLE SIGN IN] Signing out from any previous session...',
      );
      await _googleSignIn.signOut();

      debugPrint('🔐 [GOOGLE SIGN IN] Requesting Google Sign In...');
      debugPrint(
        '🔐 [GOOGLE SIGN IN] Client ID: ${_googleSignIn.clientId ?? "null (auto-detect from google-services.json)"}',
      );

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('⚠️ [GOOGLE SIGN IN] User cancelled sign in');
        _error = 'Google sign in was cancelled';
        return null;
      }

      debugPrint(
        '✅ [GOOGLE SIGN IN] Google account selected: ${googleUser.email}',
      );
      debugPrint('🔐 [GOOGLE SIGN IN] Getting authentication tokens...');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        debugPrint('❌ [GOOGLE SIGN IN] Missing authentication tokens');
        debugPrint(
          '❌ [GOOGLE SIGN IN] Access token: ${googleAuth.accessToken != null ? "present" : "null"}',
        );
        debugPrint(
          '❌ [GOOGLE SIGN IN] ID token: ${googleAuth.idToken != null ? "present" : "null"}',
        );
        throw 'Failed to get authentication tokens from Google';
      }

      debugPrint('✅ [GOOGLE SIGN IN] Authentication tokens received');
      debugPrint('🔐 [GOOGLE SIGN IN] Creating Firebase credential...');

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      debugPrint('🔐 [GOOGLE SIGN IN] Signing in with Firebase...');
      final userCredential = await _auth.signInWithCredential(credential);

      debugPrint('✅ [GOOGLE SIGN IN] Firebase sign in successful');
      debugPrint('🔐 [GOOGLE SIGN IN] User ID: ${userCredential.user?.uid}');

      // Create or update user profile in Firestore
      if (userCredential.user != null) {
        debugPrint('🔐 [GOOGLE SIGN IN] Creating/updating user profile...');
        await _createOrUpdateUserProfile(
          userCredential.user!,
          displayName: googleUser.displayName,
        );

        // Force refresh ID token to ensure currentUser is properly set
        // This prevents race conditions when making API calls immediately after login
        debugPrint('🔐 [GOOGLE SIGN IN] Refreshing ID token...');
        await userCredential.user!.getIdToken(true);

        // Add a small delay to ensure Firebase Auth state is fully propagated
        await Future.delayed(const Duration(milliseconds: 500));
        debugPrint('✅ [GOOGLE SIGN IN] Sign in process completed');
      }

      _user = userCredential.user;
      return _user;
    } catch (e, stackTrace) {
      debugPrint('❌ [GOOGLE SIGN IN] Error during sign in: $e');
      debugPrint('❌ [GOOGLE SIGN IN] Stack trace: $stackTrace');

      // Provide more helpful error messages for common issues
      final errorString = e.toString();
      if (errorString.contains('ApiException: 10') ||
          errorString.contains('DEVELOPER_ERROR') ||
          errorString.contains('sign_in_failed')) {
        debugPrint(
          '❌ [GOOGLE SIGN IN] DEVELOPER_ERROR detected - this usually means:',
        );
        debugPrint(
          '   1. SHA-1/SHA-256 fingerprints not registered in Firebase',
        );
        debugPrint(
          '   2. If using Google Play, need Google Play App Signing key SHA fingerprints',
        );
        debugPrint('   3. OAuth client ID mismatch');
        debugPrint('   4. Package name mismatch');
        _error = 'Google Sign In configuration error. Please contact support.';
      } else {
        _error = errorString;
      }

      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign in with Apple
  Future<User?> signInWithApple() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Check if Apple Sign In is available
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        throw 'Apple Sign In is not available on this device';
      }

      // Generate secure nonce for Firebase (recommended)
      final String rawNonce = _generateNonce();
      final String hashedNonce = _sha256ofString(rawNonce);

      // Request Apple Sign In
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      // Create OAuth provider credential
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: credential.identityToken,
        rawNonce: rawNonce,
        // Some Firebase versions expect the Apple authorizationCode as accessToken
        accessToken: credential.authorizationCode,
      );

      // Sign in to Firebase
      final userCredential = await _auth.signInWithCredential(oauthCredential);

      // Create or update user profile in Firestore
      if (userCredential.user != null) {
        String? displayName;
        if (credential.givenName != null && credential.familyName != null) {
          displayName = '${credential.givenName} ${credential.familyName}';
        }

        await _createOrUpdateUserProfile(
          userCredential.user!,
          displayName: displayName,
        );

        // Force refresh ID token to ensure currentUser is properly set
        // This prevents race conditions when making API calls immediately after login
        await userCredential.user!.getIdToken(true);

        // Add a delay to ensure Firebase Auth state is fully propagated
        // This is crucial for preventing "User not authenticated" errors
        await Future.delayed(const Duration(milliseconds: 1500));
      }

      _user = userCredential.user;
      return _user;
    } on SignInWithAppleAuthorizationException catch (e) {
      // Handle Apple Sign In specific errors with user-friendly messages
      switch (e.code) {
        case AuthorizationErrorCode.canceled:
          _error = 'Sign in was canceled';
          break;
        case AuthorizationErrorCode.failed:
          _error = 'Sign in failed. Please try again.';
          break;
        case AuthorizationErrorCode.invalidResponse:
          _error = 'Invalid response from Apple. Please try again.';
          break;
        case AuthorizationErrorCode.notHandled:
          _error = 'Sign in could not be completed. Please try again.';
          break;
        case AuthorizationErrorCode.unknown:
        default:
          _error = 'An unexpected error occurred during Apple sign in.';
      }
      return null;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Generates a cryptographically secure random nonce, to be included in a
  // credential request.
  String _generateNonce([int length = 32]) {
    const String charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvxyz-._';
    final Random random = Random.secure();
    return List<String>.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  // Returns the sha256 hash of [input] in hex notation.
  String _sha256ofString(String input) {
    final List<int> bytes = utf8.encode(input);
    final Digest digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Sign out
  Future<void> signOut() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      await _googleSignIn.signOut();
      await _auth.signOut();
      _user = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (kIsWeb) {
        // Web platform requires ActionCodeSettings for password reset
        // Construct the redirect URL to send users back to login after reset
        final uri = Uri.base;
        final continueUrl = uri.resolveUri(Uri(path: '/#/login')).toString();
        
        final actionCodeSettings = ActionCodeSettings(
          url: continueUrl,
          handleCodeInApp: false,
        );
        
        await _auth.sendPasswordResetEmail(
          email: email,
          actionCodeSettings: actionCodeSettings,
        );
      } else {
        // Mobile platforms don't require ActionCodeSettings
      await _auth.sendPasswordResetEmail(email: email);
      }
      return true;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          _error = 'No account found with this email address.';
          break;
        case 'invalid-email':
          _error = 'Please enter a valid email address.';
          break;
        case 'network-request-failed':
          _error = 'Network error. Please check your internet connection.';
          break;
        case 'invalid-continue-uri':
          _error = 'Invalid redirect URL configuration. Please contact support.';
          break;
        case 'unauthorized-continue-uri':
          _error = 'Redirect URL not authorized. Please contact support.';
          break;
        default:
          _error = 'Failed to send password reset email. Please try again.';
      }
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final user = _auth.currentUser;
      if (user == null) {
        throw 'No user is currently signed in';
      }

      // Call server endpoint to delete all user data
      final response = await _apiClient.authenticatedDelete('users/account');

      if (!response.success) {
        throw response.message ?? 'Failed to delete user data from server';
      }

      // After server confirms data deletion, delete the Firebase Auth account
      await user.delete();

      // Sign out from Google if signed in
      await _googleSignIn.signOut();

      _user = null;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'requires-recent-login':
          _error =
              'For security reasons, please sign out and sign back in before deleting your account.';
          break;
        case 'user-not-found':
          _error = 'User account not found.';
          break;
        default:
          _error = 'Failed to delete account: ${e.message}';
      }
      rethrow;
    } catch (e) {
      _error = 'An unexpected error occurred while deleting your account.';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
