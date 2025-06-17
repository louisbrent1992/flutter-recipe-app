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
    RecipeCollection.withName('Favorites'),
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
        return _defaultCollections;
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
        if (response.data!.isEmpty) {
          // No collections found, create default collections
          collections = _defaultCollections;
          await saveCollections(collections);
        } else {
          collections =
              response.data!
                  .map((json) => RecipeCollection.fromJson(json))
                  .toList();

          // Ensure special collections exist
          final hasFavorites = collections.any((c) => c.name == 'Favorites');
          final hasRecentlyAdded = collections.any(
            (c) => c.name == 'Recently Added',
          );

          if (!hasFavorites) {
            collections.add(RecipeCollection.withName('Favorites'));
          }
          if (!hasRecentlyAdded) {
            collections.add(RecipeCollection.withName('Recently Added'));
          }

          // Save if we added any missing collections
          if (!hasFavorites || !hasRecentlyAdded) {
            await saveCollections(collections);
          }
        }
      } else {
        logger.e('Error getting collections: ${response.message}');
        collections = _defaultCollections;
        await saveCollections(collections);
      }

      // Only update special collections if explicitly requested
      if (updateSpecialCollections) {
        // Update the recently added collection with current data
        await updateRecentlyAddedCollection(collections);
        await updateFavoritesCollection(collections);
      }

      // Cache the result AFTER all updates are complete
      _cachedCollections = collections;
      _lastCacheTime = DateTime.now();

      // Notify listeners of the update
      notifyListeners();

      return collections;
    } catch (e) {
      logger.e('Error updating collections: $e');
      return _defaultCollections;
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
        await updateCollections(forceRefresh: true);
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

      // Get all collections to find the favorites collection (use cached version)
      final collections = await getCollections(updateSpecialCollections: false);
      final favoritesCollection = collections.firstWhere(
        (c) => c.name == 'Favorites',
        orElse: () => RecipeCollection.withName('Favorites'),
      );

      // If adding to favorites collection, update the recipe's favorite status
      if (collectionId == favoritesCollection.id) {
        await RecipeService.toggleFavoriteStatus(recipe.id, true);
      }

      final response = await _api.authenticatedPost(
        'collections/$collectionId/recipes',
        body: {'recipe': recipe.toJson()},
      );

      if (response.success) {
        // Update collections after adding a recipe
        await updateCollections(forceRefresh: true);
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

      // Get all collections to find the favorites collection (use cached version)
      final collections = await getCollections(updateSpecialCollections: false);
      final favoritesCollection = collections.firstWhere(
        (c) => c.name == 'Favorites',
        orElse: () => RecipeCollection.withName('Favorites'),
      );

      // If removing from favorites collection, update the recipe's favorite status
      if (collectionId == favoritesCollection.id) {
        await RecipeService.toggleFavoriteStatus(recipeId, false);
      }

      final response = await _api.authenticatedDelete(
        'collections/$collectionId/recipes/$recipeId',
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

  // Helper method to save collections to server
  Future<void> saveCollections(List<RecipeCollection> collections) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        logger.e('No authenticated user found');
        return;
      }

      // Create each collection
      for (var collection in collections) {
        await _api.authenticatedPost('collections', body: collection.toJson());
      }
    } catch (e) {
      logger.e('Error saving collections: $e');
      rethrow;
    }
  }

  // Reset to default collections (for testing/development)
  Future<bool> resetToDefaults() async {
    try {
      await saveCollections(_defaultCollections);
      return true;
    } catch (e) {
      logger.e('Error resetting collections: $e');
      return false;
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

      if (recentlyAddedIndex == -1) {
        // If not found, create it
        collections.add(RecipeCollection.withName('Recently Added'));
        return;
      }

      // Get the last 50 recipes
      final recentRecipesResponse =
          await RecipeService.getRecentlyAddedRecipes();

      if (recentRecipesResponse.success && recentRecipesResponse.data != null) {
        final recentRecipes = recentRecipesResponse.data!;

        // Start with an empty collection to properly replace all recipes
        var updatedCollection = collections[recentlyAddedIndex].copyWith(
          recipes: [],
        );

        // Add all recently added recipes to the collection
        for (final recipe in recentRecipes) {
          updatedCollection = updatedCollection.addRecipe(recipe);
        }

        // Update the collection in the list
        collections[recentlyAddedIndex] = updatedCollection;

        // Only update the collection on the server if there are actual changes
        final currentCollection = collections[recentlyAddedIndex];
        final hasChanged =
            currentCollection.recipes.length != recentRecipes.length ||
            !currentCollection.recipes.every(
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

  Future<void> updateFavoritesCollection(
    List<RecipeCollection> collections,
  ) async {
    try {
      // Find the "Favorites" collection
      final favoritesIndex = collections.indexWhere(
        (collection) => collection.name == 'Favorites',
      );

      if (favoritesIndex == -1) {
        // If not found, create it
        collections.add(RecipeCollection.withName('Favorites'));
        return;
      }

      // Get all recipes from the database
      final allRecipesResponse = await RecipeService.getUserRecipes();

      if (allRecipesResponse.success && allRecipesResponse.data != null) {
        // The data is already converted to Recipe objects by RecipeService
        final List<Recipe> allRecipes =
            allRecipesResponse.data!['recipes'] as List<Recipe>;

        // Get all favorites from the database
        final favoritesResponse = await RecipeService.getFavoriteRecipes();

        if (favoritesResponse.success && favoritesResponse.data != null) {
          // Get the list of favorite recipe IDs
          final List<String> favoriteIds = favoritesResponse.data!;

          // Filter all recipes to only include those with IDs in the favorites list
          // Convert both to strings for comparison to handle mixed types
          final favoriteRecipes =
              allRecipes.where((recipe) {
                final recipeIdStr = recipe.id.toString();

                // First check direct ID match
                bool isMatch = favoriteIds.any(
                  (favId) => favId.toString() == recipeIdStr,
                );

                // If no direct match, check if this recipe might be a saved version of a favorited external recipe
                if (!isMatch &&
                    recipe.source != null &&
                    recipe.source != 'user-created') {
                  // For external recipes that were saved, the original external ID might be in favorites
                  // but the recipe now has a new Firestore ID
                  isMatch = favoriteIds.any((favId) {
                    final favIdStr = favId.toString();
                    // Check if the favorite ID looks like an external API ID (numeric)
                    return RegExp(r'^\d+$').hasMatch(favIdStr) &&
                        recipe.sourceUrl != null &&
                        recipe.sourceUrl!.contains(favIdStr);
                  });
                }

                return isMatch;
              }).toList();

          // Start with an empty collection to properly replace all recipes
          var updatedCollection = collections[favoritesIndex].copyWith(
            recipes: [],
          );

          // Add all favorite recipes to the collection
          for (final recipe in favoriteRecipes) {
            updatedCollection = updatedCollection.addRecipe(recipe);
          }

          // Update the collection in the list
          collections[favoritesIndex] = updatedCollection;

          // Only update the collection on the server if there are actual changes
          final currentCollection = collections[favoritesIndex];
          final hasChanged =
              currentCollection.recipes.length != favoriteRecipes.length ||
              !currentCollection.recipes.every(
                (recipe) => favoriteRecipes.any((fav) => fav.id == recipe.id),
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
          logger.e('Failed to get favorites: ${favoritesResponse.message}');
        }
      } else {
        logger.e('Error getting recipes: ${allRecipesResponse.message}');
      }
    } catch (e, stackTrace) {
      logger.e('Error updating favorites collection: $e');
      logger.e('Stack trace: $stackTrace');
      // Don't rethrow - this is a background update
    }
  }

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

        // Add to collections and save
        collections.add(updatedCollection);
        await saveCollections(collections);
        return true;
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
