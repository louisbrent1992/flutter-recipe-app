import 'package:flutter/foundation.dart';
import '../services/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class UserProfileProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Map<String, dynamic> _profile = {};
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic> get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      _profile = {};
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        _profile = doc.data() ?? {};
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading profile: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    String? displayName,
    String? email,
    String? photoURL,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Refresh authentication token before making sensitive changes
      // This prevents requires-recent-login errors
      try {
        await user.reload();
        // Force refresh the ID token to ensure it's current
        await user.getIdToken(true);
      } catch (e) {
        // If reload fails, log but continue - the update might still work
        debugPrint('Note: Could not refresh auth token (continuing anyway): $e');
      }

      // Check if user document exists
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      // Create base user data
      final userData = {
        'displayName': displayName ?? user.displayName,
        'email': email ?? user.email,
        'photoURL': photoURL ?? user.photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!userDoc.exists) {
        // If document doesn't exist, create it with additional fields
        await _firestore.collection('users').doc(user.uid).set({
          ...userData,
          'createdAt': FieldValue.serverTimestamp(),
          'uid': user.uid,
        });
      } else {
        // If document exists, update it
        await _firestore.collection('users').doc(user.uid).update(userData);
      }

      // Update Firebase Auth profile
      await _firebaseService.updateUserProfile(
        displayName: displayName,
        email: email,
        photoURL: photoURL,
      );

      await loadProfile(); // Reload profile after update
    } catch (e) {
      _error = e.toString();
      debugPrint('Error updating profile: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> uploadProfilePicture() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User is not authenticated. Please sign in first.');
    }

    // Attempt to refresh auth state to ensure we have a valid token
    try {
      await user.reload();
    } on FirebaseAuthException catch (e) {
      // Surface meaningful auth issues
      if (e.code == 'requires-recent-login' || e.code == 'user-token-expired') {
        throw Exception('Your session has expired. Please sign in again.');
      }
      rethrow;
    }

    _isLoading = true;
    notifyListeners();

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      PlatformFile file = result.files.first;
      final File imageFile = File(file.path!);
      final ext = file.extension ?? 'jpg';

      final storageRef = _storage.ref();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${user.uid}_$timestamp.$ext';
      final profilePicturesRef = storageRef.child('profile_pictures/$fileName');

      final uploadTask = await profilePicturesRef.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/$ext',
          customMetadata: {
            'uploadedBy': user.uid,
            'uploadedAt': timestamp.toString(),
          },
        ),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      await updateProfile(photoURL: downloadUrl);
    } catch (e) {
      _error = e.toString();
      if (e is FirebaseException) {
        // Handle specific Firebase errors
        if (e.code == 'unauthenticated') {
          throw Exception('Authentication error. Please sign in again.');
        } else if (e.code == 'unauthorized') {
          throw Exception('You do not have permission to upload files.');
        } else {
          throw Exception('Failed to upload profile picture: ${e.message}');
        }
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete profile picture (set photoURL to null)
  Future<void> deleteProfilePicture() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Update Firestore to remove photoURL
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        await _firestore.collection('users').doc(user.uid).update({
          'photoURL': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update Firebase Auth profile - try to delete photoURL
      // Note: Firebase Auth's updatePhotoURL may not accept null, so we'll try it
      // If it fails, that's okay - Firestore is the source of truth for the app
      try {
        // Try to set to null (may not work in all Firebase Auth versions)
        await user.updatePhotoURL(null);
      } catch (e) {
        // If updatePhotoURL doesn't accept null, that's fine
        // The app uses Firestore as source of truth, so deletion in Firestore is sufficient
        debugPrint('Note: Could not delete photoURL from Firebase Auth (this is okay): $e');
      }

      await loadProfile(); // Reload profile after deletion
    } catch (e) {
      _error = e.toString();
      debugPrint('Error deleting profile picture: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Favorites removed: add/remove/isFavorite no longer supported

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
