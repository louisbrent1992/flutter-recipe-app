import 'package:flutter/foundation.dart';
import '../services/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:io';
import '../models/recipe.dart';

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
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Clear the image cache at the start of the upload process
      await PhotoManager.clearFileCache();

      // Request permission to access photos
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (!ps.isAuth) {
        // Handle permission denial
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Get the list of asset paths (albums)
      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList();
      // Assuming you want to pick from the first album
      final AssetPathEntity path = paths.first;

      // Get assets from the selected album
      final List<AssetEntity> entities = await path.getAssetListPaged(
        page: 0,
        size: 80,
      );
      // Assuming you want to pick the first image
      final AssetEntity asset = entities.first;

      // Get the file from the asset
      final File? file = await asset.file;

      if (file == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final ext = file.path.split('.').last;
      final ref = _storage.ref().child('profile_pictures/${user.uid}.$ext');

      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      await updateProfile(photoURL: downloadUrl);
    } catch (e) {
      _error = e.toString();
      debugPrint('Error uploading profile picture: $e');
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
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('favorites')
              .get();

      _favoriteRecipes =
          snapshot.docs.map((doc) => Recipe.fromJson(doc.data())).toList();
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
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(recipe.id)
          .set(recipe.toJson());

      _favoriteRecipes.add(recipe);
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
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(recipe.id)
          .delete();

      _favoriteRecipes.removeWhere((r) => r.id == recipe.id);
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
      final doc =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('favorites')
              .doc(recipe.id)
              .get();

      return doc.exists;
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
