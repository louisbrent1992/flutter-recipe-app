import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/recipe.dart';
import '../services/google_image_service.dart';
import '../services/image_resolver_cache.dart';
import '../utils/image_validation_utils.dart';

class ImageReplacementService {

  /// Pick an image from device and upload to Firebase Storage.
  static Future<String?> pickFromDeviceAndUpload(Recipe recipe) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null) return null;
      final PlatformFile file = result.files.first;
      final path = file.path;
      if (path == null) return null;
      final user = FirebaseAuth.instance.currentUser;
      final ext = file.extension ?? 'jpg';
      final storageRef = FirebaseStorage.instance.ref();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName =
          '${user?.uid ?? 'anon'}_${recipe.id.isNotEmpty ? recipe.id : recipe.title.hashCode}_$timestamp.$ext';
      final recipeImagesRef = storageRef.child('recipe_images/$fileName');
      final uploadTask = await recipeImagesRef.putFile(
        File(path),
        SettableMetadata(
          contentType: 'image/$ext',
          customMetadata: {
            if (user != null) 'uploadedBy': user.uid,
            'uploadedAt': timestamp.toString(),
            'recipeId': recipe.id,
          },
        ),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      return null;
    }
  }

  /// Validate that a URL is an image and reachable.
  /// Blocks placeholder host, allows TikTok if it serves an actual image with image/* content-type.
  static Future<bool> validateImageUrl(String url) async {
    return await ImageValidationUtils.validateImageUrl(url);
  }

  /// Try server-backed search for an image from recipe title.
  /// Uses optimized endpoint that returns multiple validated images in one request.
  static Future<String?> searchSuggestion(String title) async {
    // Use the optimized endpoint that returns multiple validated images at once
    // Server handles validation, reducing network round trips
    final images = await GoogleImageService.fetchMultipleImages(
        '$title recipe',
      count: 3,
      );
    
    if (images.isNotEmpty) {
      return images.first;
      }
    
    return null;
  }

  /// Get multiple image suggestions for a recipe title.
  /// Useful for letting users choose from multiple options.
  static Future<List<String>> getMultipleSuggestions(
    String title, {
    int count = 3,
  }) async {
    return await GoogleImageService.fetchMultipleImages(
      '$title recipe',
      count: count,
    );
  }

  /// Persist the image URL to the recipe (client model update is handled by caller).
  static Future<bool> persistRecipeImage({
    required Recipe recipe,
    required String newImageUrl,
    required Future<Recipe?> Function(Recipe updated) saveFn,
  }) async {
    try {
      final updated = recipe.copyWith(imageUrl: newImageUrl);
      final saved = await saveFn(updated);
      return saved != null;
    } catch (e) {
      return false;
    }
  }

  /// Clear local caches so the UI reloads a fresh image.
  static Future<void> bustCaches(Recipe recipe, {String? oldUrl}) async {
    try {
      final cacheKey =
          recipe.id.isNotEmpty
              ? 'discover-${recipe.id}'
              : 'discover-${recipe.title.toLowerCase()}-${recipe.description.toLowerCase()}';
      await ImageResolverCache.delete(cacheKey);
      if (oldUrl != null && oldUrl.isNotEmpty) {
        await CachedNetworkImage.evictFromCache(oldUrl);
      }
    } catch (e) {
      print('Error busting caches: $e');
    }
  }
}
