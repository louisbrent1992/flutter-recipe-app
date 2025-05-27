import 'package:flutter/foundation.dart';
import '../services/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../models/recipe.dart';
import '../services/recipe_service.dart';

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

    // Verify the user's authentication state and get a fresh token
    try {
      await user.reload();
      if (!user.emailVerified) {
        throw Exception(
          'Please verify your email before uploading a profile picture.',
        );
      }
    } catch (e) {
      throw Exception('Authentication error. Please sign in again.');
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

  Future<void> addToFavorites(Recipe recipe) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      String recipeIdToFavorite = recipe.id;

      // Check if recipe exists in user's collection using the API
      final userRecipesResponse = await RecipeService.getUserRecipes(
        limit: 100,
      );
      bool recipeExists = false;
      Recipe? existingRecipe;

      if (userRecipesResponse.success && userRecipesResponse.data != null) {
        final userRecipes =
            userRecipesResponse.data!['recipes'] as List<Recipe>;

        // Check if recipe exists by comparing original ID or current ID
        existingRecipe = userRecipes.firstWhere(
          (r) =>
              r.id == recipe.id ||
              (r.sourceUrl != null && r.sourceUrl == recipe.sourceUrl) ||
              (r.title == recipe.title && r.description == recipe.description),
          orElse: () => Recipe(),
        );

        recipeExists = existingRecipe.id.isNotEmpty;

        if (recipeExists) {
          // Use the existing recipe's ID for favoriting
          recipeIdToFavorite = existingRecipe.id;
        }
      }

      if (!recipeExists) {
        // If recipe doesn't exist in user's collection, save it first
        final saveResponse = await RecipeService.createUserRecipe(recipe);
        if (saveResponse.success && saveResponse.data != null) {
          // Use the new saved recipe's ID for favoriting
          recipeIdToFavorite = saveResponse.data!.id;
        } else {
          throw Exception('Failed to save recipe before favoriting');
        }
      }

      // Now use the correct recipe ID to add to favorites
      final favoriteResponse = await RecipeService.toggleFavoriteStatus(
        recipeIdToFavorite,
        true,
      );

      if (!favoriteResponse.success) {
        throw Exception(
          favoriteResponse.message ?? 'Failed to add to favorites',
        );
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error adding recipe to favorites: $e');
      rethrow;
    }
  }

  Future<void> removeFromFavorites(Recipe recipe) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Use the API to remove from favorites
      final favoriteResponse = await RecipeService.toggleFavoriteStatus(
        recipe.id,
        false,
      );

      if (!favoriteResponse.success) {
        throw Exception(
          favoriteResponse.message ?? 'Failed to remove from favorites',
        );
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error removing recipe from favorites: $e');
      rethrow;
    }
  }

  Future<bool> isRecipeFavorite(Recipe recipe) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final response = await RecipeService.getFavoriteRecipes();
      if (response.success && response.data != null) {
        final favoriteIds = response.data!;
        return favoriteIds.any((id) => id.toString() == recipe.id.toString());
      }
      return false;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error checking if recipe is favorite: $e');
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
