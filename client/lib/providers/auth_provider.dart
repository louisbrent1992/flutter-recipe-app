import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/api_client.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final ApiClient _apiClient = ApiClient();

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
      if (!docSnapshot.exists) {
        // If document doesn't exist, add createdAt
        userData['createdAt'] = FieldValue.serverTimestamp();
      }

      // Update or create the document
      await userDoc.set(userData, SetOptions(merge: true));
    } catch (e) {
      print('Error creating/updating user profile: $e');
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
      }

      return _user;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: ${e.code} - ${e.message}');
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
      print('Unexpected error during sign in: $e');
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

      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('User created: ${result.user}');

      // Update display name
      await result.user!.updateDisplayName(displayName);
      _user = result.user;

      // Create user profile in Firestore
      if (_user != null) {
        await _createOrUpdateUserProfile(_user!, displayName: displayName);
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
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw 'Google sign in aborted';

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      // Create or update user profile in Firestore
      if (userCredential.user != null) {
        await _createOrUpdateUserProfile(
          userCredential.user!,
          displayName: googleUser.displayName,
        );
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
      print('FirebaseAuthException: ${e.code} - ${e.message}');
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
      print('Unexpected error sending password reset email: $e');
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
