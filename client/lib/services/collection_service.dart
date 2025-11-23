import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recipe.dart';
import '../models/recipe_collection.dart';
import '../services/recipe_service.dart';
import '../services/api_client.dart';
import 'local_storage_service.dart';

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

      // OFFLINE-FIRST: Load from local storage first
      if (!forceRefresh) {
        try {
          final localStorage = LocalStorageService();
          final localCollections = await localStorage.loadCollections();
          if (localCollections.isNotEmpty) {
            // Show cached data immediately
            _cachedCollections = localCollections;
            _lastCacheTime = DateTime.now();
            notifyListeners();
            // Continue to network fetch in background
          }
        } catch (e) {
          logger.e('Error loading collections from local storage: $e');
        }
      }

      // Check in-memory cache first
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
        // Network failed - preserve existing cached collections
        if (_cachedCollections != null && _cachedCollections!.isNotEmpty) {
          logger.w(
            'Network sync failed, using cached collections: ${response.message}',
          );
          // Don't overwrite with empty array - keep existing cache
          return _cachedCollections!;
        }
        logger.e('Error getting collections: ${response.message}');
        // Only set to empty if we have no cached data
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

      // Save to local storage (only if we have collections to save)
      if (collections.isNotEmpty) {
        try {
          final localStorage = LocalStorageService();
          await localStorage.saveCollections(collections);
        } catch (e) {
          logger.e('Error saving collections to local storage: $e');
        }
      }

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

      // OFFLINE-FIRST: Try to get from cached collections first
      RecipeCollection? cachedCollection;
      if (_cachedCollections != null) {
        try {
          cachedCollection = _cachedCollections!.firstWhere((c) => c.id == id);
          // Return cached collection immediately, then sync in background
        } catch (e) {
          // Collection not in cache
        }
      }

      // If not in cache, try to load from local storage
      if (cachedCollection == null) {
        try {
          final localStorage = LocalStorageService();
          final localCollections = await localStorage.loadCollections();
          try {
            cachedCollection = localCollections.firstWhere((c) => c.id == id);
            // Update cache if not already set
            if (_cachedCollections == null) {
              _cachedCollections = localCollections;
              _lastCacheTime = DateTime.now();
              notifyListeners();
            } else {
              // Update cache with this collection
              final index = _cachedCollections!.indexWhere((c) => c.id == id);
              if (index != -1) {
                _cachedCollections![index] = cachedCollection;
              } else {
                _cachedCollections!.add(cachedCollection);
              }
              _lastCacheTime = DateTime.now();
              notifyListeners();
            }
          } catch (e) {
            // Collection not in local storage
          }
        } catch (e) {
          logger.e('Error loading collection from local storage: $e');
        }
      }

      // If we have a cached/local collection, return it immediately
      if (cachedCollection != null) {
        // Continue to server fetch in background (non-blocking)
        _syncCollectionFromServer(id).catchError((e) {
          logger.w('Background sync failed for collection: $e');
        });
        return cachedCollection;
      }

      // Try server fetch (will update cache if successful)
      try {
        final response = await _api.authenticatedGet<Map<String, dynamic>>(
          'collections/$id',
        );

        if (response.success && response.data != null) {
          final serverCollection = RecipeCollection.fromJson(response.data!);

          // Update cache
          if (_cachedCollections != null) {
            final index = _cachedCollections!.indexWhere((c) => c.id == id);
            if (index != -1) {
              _cachedCollections![index] = serverCollection;
            } else {
              _cachedCollections!.add(serverCollection);
            }
            _lastCacheTime = DateTime.now();
            notifyListeners();

            // Save to local storage
            try {
              final localStorage = LocalStorageService();
              await localStorage.saveCollections(_cachedCollections!);
            } catch (e) {
              logger.e('Error saving collections to local storage: $e');
            }
          }

          return serverCollection;
        } else {
          logger.w('Server fetch failed: ${response.message}');
        }
      } catch (e) {
        logger.w('Network error fetching collection: $e');
      }

      // Return cached collection if available
      if (_cachedCollections != null) {
        final cachedCollection = _cachedCollections!.firstWhere(
          (c) => c.id == id,
          orElse: () => RecipeCollection.withName(''),
        );
        if (cachedCollection.id.isNotEmpty) {
          return cachedCollection;
        }
      }

      logger.e('Collection not found in cache or server');
      return null;
    } catch (e) {
      logger.e('Error getting collection: $e');
      return null;
    }
  }

  // Background sync method for collections
  Future<void> _syncCollectionFromServer(String id) async {
    try {
      final response = await _api.authenticatedGet<Map<String, dynamic>>(
        'collections/$id',
      );

      if (response.success && response.data != null) {
        final serverCollection = RecipeCollection.fromJson(response.data!);

        // Update cache
        if (_cachedCollections != null) {
          final index = _cachedCollections!.indexWhere((c) => c.id == id);
          if (index != -1) {
            _cachedCollections![index] = serverCollection;
          } else {
            _cachedCollections!.add(serverCollection);
          }
          _lastCacheTime = DateTime.now();
          notifyListeners();

          // Save to local storage
          try {
            final localStorage = LocalStorageService();
            await localStorage.saveCollections(_cachedCollections!);
          } catch (e) {
            logger.e('Error saving collections to local storage: $e');
          }
        }
      }
    } catch (e) {
      // Silently fail - we already have cached data
      logger.w('Background sync failed for collection $id: $e');
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

      // OPTIMISTIC UPDATE: Update collection locally first (works offline)
      if (_cachedCollections != null) {
        final collectionIndex = _cachedCollections!.indexWhere(
          (c) => c.id == collectionId,
        );
        if (collectionIndex != -1) {
          final collection = _cachedCollections![collectionIndex];
          // Check if recipe already in collection
          if (!collection.recipes.any((r) => r.id == recipe.id)) {
            final updatedCollection = collection.addRecipe(recipe);
            _cachedCollections![collectionIndex] = updatedCollection;

            // Save to local storage immediately
            try {
              final localStorage = LocalStorageService();
              await localStorage.saveCollections(_cachedCollections!);
            } catch (e) {
              logger.e('Error saving collections to local storage: $e');
            }

            // Notify listeners immediately
            notifyListeners();
          }
        }
      }

      // Try server sync in background (non-blocking)
      try {
        final response = await _api.authenticatedPost(
          'collections/$collectionId/recipes',
          body: {'recipe': recipe.toJson()},
        );

        if (response.success) {
          // Server sync succeeded - refresh from server to get latest state
          await updateCollections(
            forceRefresh: true,
            updateSpecialCollections: false,
          );
          return true;
        } else {
          // Server failed but local update already done
          logger.w(
            'Server sync failed, but recipe added locally: ${response.message}',
          );
          return true; // Return true because local update succeeded
        }
      } catch (e) {
        // Network error - local update already done
        logger.w('Network error, but recipe added locally: $e');
        return true; // Return true because local update succeeded
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
