import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/recipe.dart';
import '../models/recipe_collection.dart';

class CollectionService {
  static final logger = Logger();
  static const String baseUrl = 'http://localhost:3001';
  static const String _collectionsBoxName = 'collections';
  static const String _collectionsKey = 'user_recipe_collections';

  // Default collections that all users start with
  static final List<RecipeCollection> _defaultCollections = [
    RecipeCollection.withName('Breakfast'),
    RecipeCollection.withName('Lunch'),
    RecipeCollection.withName('Dinner'),
    RecipeCollection.withName('Desserts'),
    RecipeCollection.withName('Favorites'),
    RecipeCollection.withName('Recently Added'),
  ];

  // Get all collections
  static Future<List<RecipeCollection>> getCollections() async {
    try {
      // In a full implementation, this would call the API
      // For now, we'll use Hive to persist collections locally
      final box = await Hive.openBox(_collectionsBoxName);
      final collectionsJson = box.get(_collectionsKey) as List<dynamic>?;

      if (collectionsJson == null || collectionsJson.isEmpty) {
        // No collections found, return default collections
        await _saveCollections(_defaultCollections);
        return _defaultCollections;
      }

      // Convert JSON strings to RecipeCollection objects
      return collectionsJson
          .map((json) => RecipeCollection.fromJson(jsonDecode(json)))
          .cast<RecipeCollection>()
          .toList();
    } catch (e) {
      logger.e('Error getting collections: $e');
      return _defaultCollections;
    }
  }

  // Get a specific collection by ID
  static Future<RecipeCollection?> getCollection(String id) async {
    try {
      final collections = await getCollections();
      return collections.firstWhere((collection) => collection.id == id);
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
      final collections = await getCollections();

      // Check if collection with this name already exists
      if (collections.any((c) => c.name.toLowerCase() == name.toLowerCase())) {
        throw Exception('A collection with this name already exists');
      }

      // Create new collection
      final newCollection = RecipeCollection.withName(
        name,
        color: color,
        icon: icon,
      );

      // Add to existing collections and save
      collections.add(newCollection);
      await _saveCollections(collections);

      return newCollection;
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
      final collections = await getCollections();
      final index = collections.indexWhere((c) => c.id == id);

      if (index == -1) {
        throw Exception('Collection not found');
      }

      // If updating name, check for duplicates
      if (name != null) {
        final duplicateName = collections.any(
          (c) => c.id != id && c.name.toLowerCase() == name.toLowerCase(),
        );
        if (duplicateName) {
          throw Exception('A collection with this name already exists');
        }
      }

      // Update collection
      final updatedCollection = collections[index].copyWith(
        name: name,
        color: color,
        icon: icon,
      );

      // Replace old collection with updated one
      collections[index] = updatedCollection;
      await _saveCollections(collections);

      return updatedCollection;
    } catch (e) {
      logger.e('Error updating collection: $e');
      return null;
    }
  }

  // Delete a collection
  static Future<bool> deleteCollection(String id) async {
    try {
      final collections = await getCollections();
      final filteredCollections = collections.where((c) => c.id != id).toList();

      if (collections.length == filteredCollections.length) {
        return false; // Collection not found
      }

      await _saveCollections(filteredCollections);
      return true;
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
    print("Adding recipe to collection: $collectionId");
    try {
      final collections = await getCollections();
      final index = collections.indexWhere((c) => c.id == collectionId);

      if (index == -1) {
        print("Collection not found: $collectionId");
        return false; // Collection not found
      }

      // Add recipe to collection
      print(
        "Current recipes in collection: ${collections[index].recipes.length}",
      );
      final updatedCollection = collections[index].addRecipe(recipe);
      collections[index] = updatedCollection;
      print(
        "Updated recipes in collection: ${collections[index].recipes.length}",
      );

      await _saveCollections(collections);
      print("Collections saved successfully");
      return true;
    } catch (e) {
      logger.e('Error adding recipe to collection: $e');
      print("Error adding recipe to collection: $e");
      return false;
    }
  }

  // Remove a recipe from a collection
  static Future<bool> removeRecipeFromCollection(
    String collectionId,
    String recipeId,
  ) async {
    try {
      final collections = await getCollections();
      final index = collections.indexWhere((c) => c.id == collectionId);

      if (index == -1) {
        return false; // Collection not found
      }

      // Remove recipe from collection
      final updatedCollection = collections[index].removeRecipe(recipeId);
      collections[index] = updatedCollection;

      await _saveCollections(collections);
      return true;
    } catch (e) {
      logger.e('Error removing recipe from collection: $e');
      return false;
    }
  }

  // Helper method to save collections to Hive
  static Future<void> _saveCollections(
    List<RecipeCollection> collections,
  ) async {
    print("Saving ${collections.length} collections");
    try {
      final box = await Hive.openBox(_collectionsBoxName);
      final collectionsJson =
          collections
              .map((collection) => jsonEncode(collection.toJson()))
              .toList();

      // Print the first collection's recipes count before saving
      if (collections.isNotEmpty) {
        print(
          "First collection (${collections[0].name}) has ${collections[0].recipes.length} recipes",
        );
      }

      await box.put(_collectionsKey, collectionsJson);
      print("Collections saved to Hive");

      // Verify the save by reading back
      final savedJson = box.get(_collectionsKey) as List<dynamic>?;
      if (savedJson != null) {
        final savedCollections =
            savedJson
                .map((json) => RecipeCollection.fromJson(jsonDecode(json)))
                .cast<RecipeCollection>()
                .toList();

        if (collections.isNotEmpty && savedCollections.isNotEmpty) {
          print(
            "After save, first collection has ${savedCollections[0].recipes.length} recipes",
          );
        }
      }
    } catch (e) {
      logger.e('Error saving collections: $e');
      print('Error saving collections: $e');
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
}
