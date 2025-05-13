import 'package:flutter/foundation.dart';
import '../services/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../models/recipe.dart';
import '../services/collection_service.dart';
import '../models/recipe_collection.dart';

class UserProfileProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Map<String, dynamic> _profile = {};
  List<Recipe> _favoriteRecipes = [];
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic> get profile => _profile;
  List<Recipe> get favoriteRecipes => _favoriteRecipes;
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

    debugPrint('Uploading profile picture for user: ${user?.uid}');
    if (user == null) {
      debugPrint('No user logged in');
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

      debugPrint('Got fresh token for user: ${user.uid}');
    } catch (e) {
      debugPrint('Error verifying user state: $e');
      throw Exception('Authentication error. Please sign in again.');
    }

    debugPrint('Starting upload process for user: ${user.uid}');
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('Step 1: Picking image');
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null) {
        debugPrint('No image selected');
        _isLoading = false;
        notifyListeners();
        return;
      }

      PlatformFile file = result.files.first;
      debugPrint('Step 2: Image picked successfully at path: ${file.path}');

      debugPrint('Step 3: Creating file reference');
      final File imageFile = File(file.path!);
      final ext = file.extension ?? 'jpg';
      debugPrint('File extension: $ext');

      debugPrint('Step 4: Creating storage references');
      final storageRef = _storage.ref();
      debugPrint('Root storage reference created');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${user.uid}_$timestamp.$ext';
      debugPrint('Generated filename: $fileName');

      final profilePicturesRef = storageRef.child('profile_pictures/$fileName');
      debugPrint(
        'Profile pictures reference created at: ${profilePicturesRef.fullPath}',
      );

      debugPrint('Step 5: Starting file upload');
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
      debugPrint('File upload completed');

      debugPrint('Step 6: Getting download URL');
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      debugPrint('Download URL obtained: $downloadUrl');

      debugPrint('Step 7: Updating user profile');
      await updateProfile(photoURL: downloadUrl);
      debugPrint('Profile update completed');
    } catch (e) {
      _error = e.toString();
      debugPrint('Error in uploadProfilePicture: $e');
      if (e is FirebaseException) {
        debugPrint('Firebase error code: ${e.code}');
        debugPrint('Firebase error message: ${e.message}');
        debugPrint('Firebase error details: ${e.plugin}');

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

  Future<void> getFavoriteRecipes() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final snapshot =
          await _firestore.collection('favorites').doc(user.uid).get();

      if (!snapshot.exists) {
        _favoriteRecipes = [];
      } else {
        // If document exists, get the recipes array
        List<dynamic> recipeIds = snapshot.data()?['recipes'] ?? [];
        _favoriteRecipes = [];

        // Get each recipe by ID
        for (String recipeId in recipeIds) {
          final recipeDoc =
              await _firestore.collection('recipes').doc(recipeId).get();

          if (recipeDoc.exists) {
            final recipeData = recipeDoc.data();
            if (recipeData != null) {
              _favoriteRecipes.add(
                Recipe.fromJson({'id': recipeDoc.id, ...recipeData}),
              );
            }
          }
        }
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading favorite recipes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addToFavorites(Recipe recipe) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Add the recipe ID to the favorites array
      await _firestore.collection('favorites').doc(user.uid).set({
        'recipes': FieldValue.arrayUnion([recipe.id]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update UI
      if (!_favoriteRecipes.any((r) => r.id == recipe.id)) {
        _favoriteRecipes.add(recipe);
        notifyListeners();
      }

      // Update Favorites collection in CollectionService
      await _updateFavoritesCollection();
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
      // Remove the recipe ID from the favorites array
      await _firestore.collection('favorites').doc(user.uid).update({
        'recipes': FieldValue.arrayRemove([recipe.id]),
      });

      // Update UI
      _favoriteRecipes.removeWhere((r) => r.id == recipe.id);
      notifyListeners();

      // Update Favorites collection in CollectionService
      await _updateFavoritesCollection();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error removing recipe from favorites: $e');
      rethrow;
    }
  }

  // Helper method to update the Favorites collection
  Future<void> _updateFavoritesCollection() async {
    try {
      // Get all collections
      final collections = await CollectionService.getCollections();

      // Find the Favorites collection
      final favoritesCollection = collections.firstWhere(
        (collection) => collection.name == 'Favorites',
        orElse: () => RecipeCollection.withName('Favorites'),
      );

      // Create a fresh collection with current favorites
      var updatedCollection = favoritesCollection.copyWith(recipes: []);

      // Add all favorite recipes to the collection
      for (final recipe in _favoriteRecipes) {
        updatedCollection = updatedCollection.addRecipe(recipe);
      }

      // Save the updated collection
      await CollectionService.updateCollection(
        updatedCollection.id,
        name: updatedCollection.name,
      );

      // Force a refresh of the collection
      await CollectionService.getCollections();
    } catch (e) {
      debugPrint('Error updating favorites collection: $e');
      // Continue silently as this is just a convenience update
    }
  }

  Future<bool> isRecipeFavorite(Recipe recipe) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore.collection('favorites').doc(user.uid).get();

      if (!doc.exists) return false;

      final List<dynamic> recipes = doc.data()?['recipes'] ?? [];
      return recipes.contains(recipe.id);
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
