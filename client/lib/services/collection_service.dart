import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recipe.dart';
import '../models/recipe_collection.dart';
import '../services/recipe_service.dart';
import '../services/api_client.dart';

class CollectionService extends ChangeNotifier {
  static final logger = Logger();
  static final ApiClient _api = ApiClient();
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache to prevent repeated API calls
  static List<RecipeCollection>? _cachedCollections;
  static DateTime? _lastCacheTime;
  static const Duration _cacheTimeout = Duration(minutes: 2);

  // Default collections that all users start with
  static final List<RecipeCollection> _defaultCollections = [
    RecipeCollection.withName('Recently Added'),
  ];

  // Centralized method to update collections
  Future<List<RecipeCollection>> updateCollections({
    bool forceRefresh = false,
    bool updateSpecialCollections = true,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        logger.e('No authenticated user found');
        return [];
      }

      // Always clear cache when force refresh is requested
      if (forceRefresh) {
        _clearCache();
      }

      // Check cache first
      if (!forceRefresh &&
          _cachedCollections != null &&
          _lastCacheTime != null) {
        final timeSinceCache = DateTime.now().difference(_lastCacheTime!);
        if (timeSinceCache < _cacheTimeout) {
          return _cachedCollections!;
        }
      }

      final response = await _api.authenticatedGet<List<dynamic>>(
        'collections',
      );

      List<RecipeCollection> collections;
      if (response.success && response.data != null) {
        collections =
            response.data!
                .map((json) => RecipeCollection.fromJson(json))
                .toList();

        // Deduplicate any accidental duplicates of "Recently Added" by keeping the most recently updated
        final recentlyAddedCollections =
            collections.where((c) => c.name == 'Recently Added').toList();
        if (recentlyAddedCollections.length > 1) {
          recentlyAddedCollections.sort(
            (a, b) => b.updatedAt.compareTo(a.updatedAt),
          );
          final keepId = recentlyAddedCollections.first.id;
          collections =
              collections
                  .where((c) => !(c.name == 'Recently Added' && c.id != keepId))
                  .toList();
        }
      } else {
        logger.e('Error getting collections: ${response.message}');
        collections = [];
      }

      // Only update special collections if explicitly requested
      if (updateSpecialCollections) {
        // Update the recently added collection with current data
        await updateRecentlyAddedCollection(collections);
      }

      // Cache the result AFTER all updates are complete
      _cachedCollections = collections;
      _lastCacheTime = DateTime.now();

      // Notify listeners of the update
      notifyListeners();

      return collections;
    } catch (e) {
      logger.e('Error updating collections: $e');
      return [];
    }
  }

  // Get all collections with caching
  Future<List<RecipeCollection>> getCollections({
    bool forceRefresh = false,
    bool updateSpecialCollections = true,
  }) async {
    return updateCollections(
      forceRefresh: forceRefresh,
      updateSpecialCollections: updateSpecialCollections,
    );
  }

  // Clear cache when collections are modified
  static void _clearCache() {
    _cachedCollections = null;
    _lastCacheTime = null;
  }

  // Get a specific collection by ID
  Future<RecipeCollection?> getCollection(String id) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        logger.e('No authenticated user found');
        return null;
      }

      final response = await _api.authenticatedGet<Map<String, dynamic>>(
        'collections/$id',
      );

      if (response.success && response.data != null) {
        return RecipeCollection.fromJson(response.data!);
      } else {
        logger.e('Error getting collection: ${response.message}');
        return null;
      }
    } catch (e) {
      logger.e('Error getting collection: $e');
      return null;
    }
  }

  // Create a new collection
  Future<RecipeCollection?> createCollection(String name) async {
    try {
      logger.i('Creating collection: $name');
      final user = _auth.currentUser;
      if (user == null) {
        logger.e('No authenticated user found');
        return null;
      }

      // Create a collection with predefined icon (and optionally custom color)
      final Map<String, dynamic> body =
          RecipeCollection.withName(name).toJson();

      final response = await _api.authenticatedPost<Map<String, dynamic>>(
        'collections',
        body: body,
      );

      if (response.success && response.data != null) {
        // Update collections after creating a new one
        // Skip updating special collections to avoid duplicate getRecentlyAddedRecipes calls
        await updateCollections(
          forceRefresh: true,
          updateSpecialCollections: false,
        );
        return RecipeCollection.fromJson(response.data!);
      } else {
        throw Exception(response.message ?? 'Failed to create collection');
      }
    } catch (e) {
      logger.e('Error creating collection: $e');
      return null;
    }
  }

  // Update an existing collection
  Future<RecipeCollection?> updateCollection(
    String id, {
    String? name,
    Color? color,
  }) async {
    try {
      logger.i('Updating collection: $id');
      final user = _auth.currentUser;
      if (user == null) {
        logger.e('No authenticated user found');
        return null;
      }

      // Create a map with only non-null values
      final Map<String, dynamic> body = {};
      if (name != null) body['name'] = name;
      if (color != null) body['color'] = color.toARGB32();

      final response = await _api.authenticatedPut<Map<String, dynamic>>(
        'collections/$id',
        body: body,
      );

      if (response.success && response.data != null) {
        // Update collections after modifying one
        await updateCollections(forceRefresh: true);
        return RecipeCollection.fromJson(response.data!);
      } else {
        throw Exception(response.message ?? 'Failed to update collection');
      }
    } catch (e) {
      logger.e('Error updating collection: $e');
      return null;
    }
  }

  // Delete a collection
  Future<bool> deleteCollection(String id) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        logger.e('No authenticated user found');
        return false;
      }

      final response = await _api.authenticatedDelete('collections/$id');
      if (response.success) {
        // Update collections after deleting one
        await updateCollections(forceRefresh: true);
      }
      return response.success;
    } catch (e) {
      logger.e('Error deleting collection: $e');
      return false;
    }
  }

  // Add a recipe to a collection
  Future<bool> addRecipeToCollection(String collectionId, Recipe recipe) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        logger.e('No authenticated user found');
        return false;
      }

      // Collection ID is already provided, no need to fetch all collections
      final response = await _api.authenticatedPost(
        'collections/$collectionId/recipes',
        body: {'recipe': recipe.toJson()},
      );

      if (response.success) {
        // Update collections after adding a recipe (this will refresh the cache)
        // Skip updating special collections to avoid duplicate getRecentlyAddedRecipes calls
        // The recently added collection will be updated on next full refresh
        await updateCollections(
          forceRefresh: true,
          updateSpecialCollections: false,
        );
        return true;
      } else {
        throw Exception(
          response.message ?? 'Failed to add recipe to collection',
        );
      }
    } catch (e) {
      logger.e('Error adding recipe to collection: $e');
      return false;
    }
  }

  // Remove a recipe from a collection
  Future<bool> removeRecipeFromCollection(
    String collectionId,
    String recipeId,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        logger.e('No authenticated user found');
        return false;
      }

      // Resolve real collection ID if a name was provided
      await getCollections(updateSpecialCollections: false);
      final targetCollectionId = collectionId;

      final response = await _api.authenticatedDelete(
        'collections/$targetCollectionId/recipes/$recipeId',
      );

      if (response.success) {
        // Update collections after removing a recipe
        await updateCollections(forceRefresh: true);
      }
      return response.success;
    } catch (e) {
      logger.e('Error removing recipe from collection: $e');
      return false;
    }
  }

  // Helper method to create default collections for a new user
  Future<void> createDefaultCollections() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        logger.e('No authenticated user found');
        return;
      }

      logger.i('Creating default collections for new user: ${user.uid}');

      // Create each default collection
      for (var collection in _defaultCollections) {
        await _api.authenticatedPost('collections', body: collection.toJson());
      }

      // Clear cache to force refresh
      _clearCache();

      logger.i('Default collections created successfully');
    } catch (e) {
      logger.e('Error creating default collections: $e');
      rethrow;
    }
  }

  // Update the "Recently Added" collection with the last 50 recipes
  Future<void> updateRecentlyAddedCollection(
    List<RecipeCollection> collections,
  ) async {
    try {
      // Find the "Recently Added" collection
      final recentlyAddedIndex = collections.indexWhere(
        (collection) => collection.name == 'Recently Added',
      );

      // Get the last 50 recipes
      final recentRecipesResponse =
          await RecipeService.getRecentlyAddedRecipes();

      if (recentRecipesResponse.success && recentRecipesResponse.data != null) {
        final recentRecipes = recentRecipesResponse.data!;

        // Capture current collection before modifying for change detection
        if (recentlyAddedIndex == -1) {
          // If the collection doesn't exist, create it locally and persist to server
          var newCollection = RecipeCollection.withName(
            'Recently Added',
          ).copyWith(recipes: []);
          for (final recipe in recentRecipes) {
            newCollection = newCollection.addRecipe(recipe);
          }
          // Create on server
          final response = await _api.authenticatedPost<Map<String, dynamic>>(
            'collections',
            body: newCollection.toJson(),
          );
          if (response.success && response.data != null) {
            collections.add(RecipeCollection.fromJson(response.data!));
          }
          return; // Done; next refresh will pick it up
        }

        final priorCollection = collections[recentlyAddedIndex];
        // Build updated collection deterministically
        var updatedCollection = priorCollection.copyWith(recipes: []);

        // Add all recently added recipes to the collection
        for (final recipe in recentRecipes) {
          updatedCollection = updatedCollection.addRecipe(recipe);
        }

        // Update the collection in the list
        collections[recentlyAddedIndex] = updatedCollection;

        // Only update the collection on the server if there are actual changes
        final hasChanged =
            priorCollection.recipes.length != recentRecipes.length ||
            !priorCollection.recipes.every(
              (recipe) => recentRecipes.any((recent) => recent.id == recipe.id),
            );

        if (hasChanged) {
          // Update the collection on the server with the full collection data
          final tempCache = _cachedCollections;
          final tempCacheTime = _lastCacheTime;
          await _api.authenticatedPut(
            'collections/${updatedCollection.id}',
            body: updatedCollection.toJson(),
          );
          // Restore cache since this is an internal update
          _cachedCollections = tempCache;
          _lastCacheTime = tempCacheTime;
        }
      } else {
        // Log the error but don't throw - just keep the existing collection
        logger.e(
          'Error getting recently added recipes: ${recentRecipesResponse.message}',
        );
      }
    } catch (e) {
      logger.e('Error updating recently added collection: $e');
      // Continue silently - this is a convenience feature
    }
  }

  // Favorites removed: no Favorites collection sync

  // Update a collection directly with the given recipes
  Future<bool> updateCollectionRecipes(
    String collectionName,
    List<Recipe> recipes,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        logger.e('No authenticated user found');
        return false;
      }

      // Get all collections
      final collections = await getCollections();

      // Find the collection by name
      final index = collections.indexWhere((c) => c.name == collectionName);

      if (index == -1) {
        // If not found, create a new collection with these recipes
        final newCollection = RecipeCollection.withName(collectionName);

        // Add all recipes
        var updatedCollection = newCollection;
        for (final recipe in recipes) {
          updatedCollection = updatedCollection.addRecipe(recipe);
        }

        // Create the collection using the API
        final response = await _api.authenticatedPost<Map<String, dynamic>>(
          'collections',
          body: updatedCollection.toJson(),
        );

        if (response.success) {
          // Update collections after creating a new one
          await updateCollections(forceRefresh: true);
          return true;
        } else {
          throw Exception(response.message ?? 'Failed to create collection');
        }
      }

      // Update existing collection - replace all recipes
      var updatedCollection = collections[index].copyWith(recipes: []);

      // Add all recipes
      for (final recipe in recipes) {
        updatedCollection = updatedCollection.addRecipe(recipe);
      }

      // Update the collection
      final result = await updateCollection(
        updatedCollection.id,
        name: updatedCollection.name,
      );

      return result != null;
    } catch (e) {
      logger.e('Error updating collection recipes: $e');
      return false;
    }
  }

  // Refresh collections after recipe deletion to ensure consistency
  Future<void> refreshCollectionsAfterRecipeDeletion(String recipeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        logger.e('No authenticated user found');
        return;
      }

      // Update collections after recipe deletion
      await updateCollections(forceRefresh: true);
      logger.i('Collections updated after recipe $recipeId deletion');
    } catch (e) {
      logger.e('Error refreshing collections after recipe deletion: $e');
      // Continue silently - this is a cleanup operation
    }
  }
}
