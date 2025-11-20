import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../services/api_client.dart';
import '../services/collection_service.dart';
import '../services/credits_service.dart';
import '../services/invite_service.dart';
import '../firebase_options.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // Use correct iOS client ID from GoogleService-Info.plist
    clientId:
        defaultTargetPlatform == TargetPlatform.iOS
            ? '826154873845-9n1vqk797jnrvarkd3stsehjhl6ff1le.apps.googleusercontent.com'
            : DefaultFirebaseOptions.android.androidClientId,
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
      final bool isNewUser = result.additionalUserInfo?.isNewUser ?? false;

      // Update display name
      await result.user!.updateDisplayName(displayName);
      _user = result.user;

      // Create user profile in Firestore
      if (_user != null) {
        await _createOrUpdateUserProfile(_user!, displayName: displayName);
        await _user!.getIdToken(true);
        await Future.delayed(const Duration(milliseconds: 500));
        if (isNewUser) {
          await InviteService().applyPendingInvite();
        }
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
      // Ensure we're signed out first to avoid cached state issues
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _error = 'Google sign in was cancelled';
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw 'Failed to get authentication tokens from Google';
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final bool isNewUser =
          userCredential.additionalUserInfo?.isNewUser ?? false;

      // Create or update user profile in Firestore
      if (userCredential.user != null) {
        await _createOrUpdateUserProfile(
          userCredential.user!,
          displayName: googleUser.displayName,
        );

        // Force refresh ID token to ensure currentUser is properly set
        // This prevents race conditions when making API calls immediately after login
        await userCredential.user!.getIdToken(true);

        // Add a small delay to ensure Firebase Auth state is fully propagated
        await Future.delayed(const Duration(milliseconds: 500));

        if (isNewUser) {
          await InviteService().applyPendingInvite();
        }
      }

      _user = userCredential.user;
      return _user;
    } catch (e) {
      _error = e.toString();
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
      final bool isNewUser =
          userCredential.additionalUserInfo?.isNewUser ?? false;

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

        if (isNewUser) {
          await InviteService().applyPendingInvite();
        }
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
      await _auth.sendPasswordResetEmail(email: email);
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
