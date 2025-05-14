import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recipe.dart';
import '../models/recipe_collection.dart';
import '../services/recipe_service.dart';
import '../services/api_client.dart';

class CollectionService {
  static final logger = Logger();
  static final ApiClient _api = ApiClient();
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Default collections that all users start with
  static final List<RecipeCollection> _defaultCollections = [
    RecipeCollection.withName('Favorites'),
    RecipeCollection.withName('Recently Added'),
  ];

  // Get all collections
  static Future<List<RecipeCollection>> getCollections() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        logger.e('No authenticated user found');
        return _defaultCollections;
      }

      final response = await _api.authenticatedGet<List<dynamic>>(
        'collections',
      );

      List<RecipeCollection> collections;
      if (response.success && response.data != null) {
        if (response.data!.isEmpty) {
          // No collections found, create default collections
          collections = _defaultCollections;
          await _saveCollections(collections);
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
            await _saveCollections(collections);
          }
        }
      } else {
        logger.e('Error getting collections: ${response.message}');
        collections = _defaultCollections;
        await _saveCollections(collections);
      }

      // Update the recently added collection with current data
      await _updateRecentlyAddedCollection(collections);
      await _updateFavoritesCollection(collections);

      return collections;
    } catch (e) {
      logger.e('Error getting collections: $e');
      return _defaultCollections;
    }
  }

  // Get a specific collection by ID
  static Future<RecipeCollection?> getCollection(String id) async {
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
  static Future<RecipeCollection?> createCollection(
    String name, {
    Color? color,
    IconData? icon,
  }) async {
    try {
      logger.i('Creating collection: $name');
      final user = _auth.currentUser;
      if (user == null) {
        logger.e('No authenticated user found');
        return null;
      }

      // Create a map with only non-null values
      final Map<String, dynamic> body = {'name': name};
      if (color != null) {
        body['color'] = color.toARGB32();
      }
      if (icon != null) {
        body['icon'] = {
          'codePoint': icon.codePoint,
          'fontFamily': icon.fontFamily,
          'fontPackage': icon.fontPackage,
        };
      }

      final response = await _api.authenticatedPost<Map<String, dynamic>>(
        'collections',
        body: body,
      );

      if (response.success && response.data != null) {
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
  static Future<RecipeCollection?> updateCollection(
    String id, {
    String? name,
    Color? color,
    IconData? icon,
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
      if (icon != null) {
        body['icon'] = {
          'codePoint': icon.codePoint,
          'fontFamily': icon.fontFamily,
          'fontPackage': icon.fontPackage,
        };
      }

      final response = await _api.authenticatedPut<Map<String, dynamic>>(
        'collections/$id',
        body: body,
      );

      if (response.success && response.data != null) {
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
  static Future<bool> deleteCollection(String id) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        logger.e('No authenticated user found');
        return false;
      }

      final response = await _api.authenticatedDelete('collections/$id');
      return response.success;
    } catch (e) {
      logger.e('Error deleting collection: $e');
      return false;
    }
  }

  // Add a recipe to a collection
  static Future<bool> addRecipeToCollection(
    String collectionId,
    Recipe recipe,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        logger.e('No authenticated user found');
        return false;
      }

      // Get all collections to find the favorites collection
      final collections = await getCollections();
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
  static Future<bool> removeRecipeFromCollection(
    String collectionId,
    String recipeId,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        logger.e('No authenticated user found');
        return false;
      }

      // Get all collections to find the favorites collection
      final collections = await getCollections();
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

      return response.success;
    } catch (e) {
      logger.e('Error removing recipe from collection: $e');
      return false;
    }
  }

  // Helper method to save collections to server
  static Future<void> _saveCollections(
    List<RecipeCollection> collections,
  ) async {
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
  static Future<bool> resetToDefaults() async {
    try {
      await _saveCollections(_defaultCollections);
      return true;
    } catch (e) {
      logger.e('Error resetting collections: $e');
      return false;
    }
  }

  // Update the "Recently Added" collection with recipes from the last 7 days
  static Future<void> _updateRecentlyAddedCollection(
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

      // Get recipes from last 7 days
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

        // Update the collection on the server
        await updateCollection(
          updatedCollection.id,
          name: updatedCollection.name,
        );
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

  static Future<void> _updateFavoritesCollection(
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
        final allRecipes = allRecipesResponse.data!['recipes'] as List<Recipe>;

        // Get all favorites from the database
        final favoritesResponse = await RecipeService.getFavoriteRecipes();

        if (favoritesResponse.success && favoritesResponse.data != null) {
          // Get the list of favorite recipe IDs
          final favoriteIds = favoritesResponse.data!;

          // Filter all recipes to only include those with IDs in the favorites list
          final favoriteRecipes =
              allRecipes
                  .where((recipe) => favoriteIds.contains(recipe.id))
                  .toList();

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

          // Update the collection on the server
          await updateCollection(
            updatedCollection.id,
            name: updatedCollection.name,
          );
        }
      } else {
        logger.e('Error getting recipes: ${allRecipesResponse.message}');
      }
    } catch (e) {
      logger.e('Error updating favorites collection: $e');
    }
  }

  // Update a collection directly with the given recipes
  static Future<bool> updateCollectionRecipes(
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
        await _saveCollections(collections);
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
}
