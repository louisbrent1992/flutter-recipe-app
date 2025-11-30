import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../models/recipe.dart';
import '../models/recipe_collection.dart';

/// Service for persistent local storage using Hive
/// Stores user recipes, collections, and discover cache for offline access
class LocalStorageService {
  LocalStorageService._internal();
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;

  static const String _userRecipesBox = 'user_recipes';
  static const String _collectionsBox = 'collections';
  static const String _discoverCacheBox = 'discover_cache';
  static const String _communityCacheBox = 'community_cache';
  static const String _metadataBox = 'storage_metadata';

  // Cache expiration durations
  static const Duration _recipesCacheDuration = Duration(days: 7);
  static const Duration _collectionsCacheDuration = Duration(days: 7);
  static const Duration _discoverCacheDuration = Duration(hours: 1);
  static const Duration _communityCacheDuration = Duration(hours: 1);

  Box? _userRecipesBoxInstance;
  Box? _collectionsBoxInstance;
  Box? _discoverCacheBoxInstance;
  Box? _communityCacheBoxInstance;
  Box? _metadataBoxInstance;

  /// Initialize all Hive boxes
  Future<void> initialize() async {
    try {
      _userRecipesBoxInstance = await Hive.openBox(_userRecipesBox);
      _collectionsBoxInstance = await Hive.openBox(_collectionsBox);
      _discoverCacheBoxInstance = await Hive.openBox(_discoverCacheBox);
      _communityCacheBoxInstance = await Hive.openBox(_communityCacheBox);
      _metadataBoxInstance = await Hive.openBox(_metadataBox);
      
      if (kDebugMode) {
        debugPrint('✅ LocalStorageService: All boxes initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ LocalStorageService: Error initializing boxes: $e');
      }
      rethrow;
    }
  }

  // ==================== User Recipes ====================

  /// Save user recipes to local storage
  Future<void> saveUserRecipes(List<Recipe> recipes) async {
    try {
      final box = _userRecipesBoxInstance;
      if (box == null) {
        await initialize();
        return saveUserRecipes(recipes);
      }

      // Convert recipes to JSON
      final recipesJson = recipes.map((r) => r.toJson()).toList();
      
      // Save recipes
      await box.put('recipes', recipesJson);
      
      // Save metadata (timestamp)
      await _saveMetadata('user_recipes_timestamp', DateTime.now().toIso8601String());
      
      if (kDebugMode) {
        debugPrint('💾 Saved ${recipes.length} user recipes to local storage');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error saving user recipes: $e');
      }
    }
  }

  /// Load user recipes from local storage
  Future<List<Recipe>> loadUserRecipes() async {
    try {
      final box = _userRecipesBoxInstance;
      if (box == null) {
        await initialize();
        return loadUserRecipes();
      }

      // Check if cache is expired
      final timestamp = await _getMetadata('user_recipes_timestamp');
      if (timestamp != null) {
        final cacheTime = DateTime.parse(timestamp);
        if (DateTime.now().difference(cacheTime) > _recipesCacheDuration) {
          if (kDebugMode) {
            debugPrint('⏰ User recipes cache expired');
          }
          return [];
        }
      }

      final recipesJson = box.get('recipes') as List?;
      if (recipesJson == null) {
        return [];
      }

      // Convert dynamic maps to Map<String, dynamic> to avoid type casting errors
      final recipes = recipesJson
          .map((json) {
            // Handle Hive's _Map<dynamic, dynamic> type
            if (json is Map) {
              final Map<String, dynamic> converted = {};
              json.forEach((key, value) {
                converted[key.toString()] = value;
              });
              return Recipe.fromJson(converted);
            }
            return Recipe.fromJson(json as Map<String, dynamic>);
          })
          .toList();

      if (kDebugMode) {
        debugPrint('📦 Loaded ${recipes.length} user recipes from local storage');
      }

      return recipes;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading user recipes: $e');
      }
      return [];
    }
  }

  /// Save a single user recipe (for optimistic updates)
  Future<void> saveUserRecipe(Recipe recipe) async {
    try {
      final recipes = await loadUserRecipes();
      // Remove existing recipe with same ID if present
      recipes.removeWhere((r) => r.id == recipe.id);
      // Add new/updated recipe
      recipes.add(recipe);
      await saveUserRecipes(recipes);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error saving single user recipe: $e');
      }
    }
  }

  /// Delete a user recipe from local storage
  Future<void> deleteUserRecipe(String recipeId) async {
    try {
      final recipes = await loadUserRecipes();
      recipes.removeWhere((r) => r.id == recipeId);
      await saveUserRecipes(recipes);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error deleting user recipe: $e');
      }
    }
  }

  // ==================== Collections ====================

  /// Save collections to local storage
  Future<void> saveCollections(List<RecipeCollection> collections) async {
    try {
      final box = _collectionsBoxInstance;
      if (box == null) {
        await initialize();
        return saveCollections(collections);
      }

      // Convert collections to JSON
      final collectionsJson = collections.map((c) => c.toJson()).toList();
      
      // Save collections
      await box.put('collections', collectionsJson);
      
      // Save metadata (timestamp)
      await _saveMetadata('collections_timestamp', DateTime.now().toIso8601String());
      
      if (kDebugMode) {
        debugPrint('💾 Saved ${collections.length} collections to local storage');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error saving collections: $e');
      }
    }
  }

  /// Load collections from local storage
  Future<List<RecipeCollection>> loadCollections() async {
    try {
      final box = _collectionsBoxInstance;
      if (box == null) {
        await initialize();
        return loadCollections();
      }

      // Check if cache is expired
      final timestamp = await _getMetadata('collections_timestamp');
      if (timestamp != null) {
        final cacheTime = DateTime.parse(timestamp);
        if (DateTime.now().difference(cacheTime) > _collectionsCacheDuration) {
          if (kDebugMode) {
            debugPrint('⏰ Collections cache expired');
          }
          return [];
        }
      }

      final collectionsJson = box.get('collections') as List?;
      if (collectionsJson == null) {
        return [];
      }

      // Convert dynamic maps to Map<String, dynamic> to avoid type casting errors
      final collections = collectionsJson
          .map((json) {
            // Handle Hive's _Map<dynamic, dynamic> type
            if (json is Map) {
              final Map<String, dynamic> converted = {};
              json.forEach((key, value) {
                // Handle nested recipe maps if present
                if (key.toString() == 'recipes' && value is List) {
                  converted[key.toString()] = value.map((recipeJson) {
                    if (recipeJson is Map) {
                      final Map<String, dynamic> recipeConverted = {};
                      recipeJson.forEach((k, v) {
                        recipeConverted[k.toString()] = v;
                      });
                      return recipeConverted;
                    }
                    return recipeJson;
                  }).toList();
                } else {
                  converted[key.toString()] = value;
                }
              });
              return RecipeCollection.fromJson(converted);
            }
            return RecipeCollection.fromJson(json as Map<String, dynamic>);
          })
          .toList();

      if (kDebugMode) {
        debugPrint('📦 Loaded ${collections.length} collections from local storage');
      }

      return collections;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading collections: $e');
      }
      return [];
    }
  }

  // ==================== Discover Cache ====================

  /// Save discover cache to local storage
  Future<void> saveDiscoverCache(List<Recipe> recipes) async {
    try {
      final box = _discoverCacheBoxInstance;
      if (box == null) {
        await initialize();
        return saveDiscoverCache(recipes);
      }

      // Convert recipes to JSON
      final recipesJson = recipes.map((r) => r.toJson()).toList();
      
      // Save cache
      await box.put('cache', recipesJson);
      
      // Save metadata (timestamp)
      await _saveMetadata('discover_cache_timestamp', DateTime.now().toIso8601String());
      
      if (kDebugMode) {
        debugPrint('💾 Saved ${recipes.length} recipes to discover cache');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error saving discover cache: $e');
      }
    }
  }

  /// Load discover cache from local storage
  Future<List<Recipe>> loadDiscoverCache() async {
    try {
      final box = _discoverCacheBoxInstance;
      if (box == null) {
        await initialize();
        return loadDiscoverCache();
      }

      // Check if cache is expired
      final timestamp = await _getMetadata('discover_cache_timestamp');
      if (timestamp != null) {
        final cacheTime = DateTime.parse(timestamp);
        if (DateTime.now().difference(cacheTime) > _discoverCacheDuration) {
          if (kDebugMode) {
            debugPrint('⏰ Discover cache expired');
          }
          return [];
        }
      }

      final recipesJson = box.get('cache') as List?;
      if (recipesJson == null) {
        return [];
      }

      // Convert dynamic maps to Map<String, dynamic> to avoid type casting errors
      final recipes = recipesJson
          .map((json) {
            // Handle Hive's _Map<dynamic, dynamic> type
            if (json is Map) {
              final Map<String, dynamic> converted = {};
              json.forEach((key, value) {
                converted[key.toString()] = value;
              });
              return Recipe.fromJson(converted);
            }
            return Recipe.fromJson(json as Map<String, dynamic>);
          })
          .toList();

      if (kDebugMode) {
        debugPrint('📦 Loaded ${recipes.length} recipes from discover cache');
      }

      return recipes;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading discover cache: $e');
      }
      return [];
    }
  }

  /// Clear discover cache
  Future<void> clearDiscoverCache() async {
    try {
      final box = _discoverCacheBoxInstance;
      if (box == null) return;
      
      await box.clear();
      await _metadataBoxInstance?.delete('discover_cache_timestamp');
      
      if (kDebugMode) {
        debugPrint('🗑️ Cleared discover cache');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error clearing discover cache: $e');
      }
    }
  }

  // ==================== Community Cache ====================

  /// Save community cache to local storage
  Future<void> saveCommunityCache(List<Recipe> recipes) async {
    try {
      final box = _communityCacheBoxInstance;
      if (box == null) {
        await initialize();
        return saveCommunityCache(recipes);
      }

      // Convert recipes to JSON
      final recipesJson = recipes.map((r) => r.toJson()).toList();
      
      // Save cache
      await box.put('cache', recipesJson);
      
      // Save metadata (timestamp)
      await _saveMetadata('community_cache_timestamp', DateTime.now().toIso8601String());
      
      if (kDebugMode) {
        debugPrint('💾 Saved ${recipes.length} recipes to community cache');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error saving community cache: $e');
      }
    }
  }

  /// Load community cache from local storage
  Future<List<Recipe>> loadCommunityCache() async {
    try {
      final box = _communityCacheBoxInstance;
      if (box == null) {
        await initialize();
        return loadCommunityCache();
      }

      // Check if cache is expired
      final timestamp = await _getMetadata('community_cache_timestamp');
      if (timestamp != null) {
        final cacheTime = DateTime.parse(timestamp);
        if (DateTime.now().difference(cacheTime) > _communityCacheDuration) {
          if (kDebugMode) {
            debugPrint('⏰ Community cache expired');
          }
          return [];
        }
      }

      final recipesJson = box.get('cache') as List?;
      if (recipesJson == null) {
        return [];
      }

      // Convert dynamic maps to Map<String, dynamic> to avoid type casting errors
      final recipes = recipesJson
          .map((json) {
            // Handle Hive's _Map<dynamic, dynamic> type
            if (json is Map) {
              final Map<String, dynamic> converted = {};
              json.forEach((key, value) {
                converted[key.toString()] = value;
              });
              return Recipe.fromJson(converted);
            }
            return Recipe.fromJson(json as Map<String, dynamic>);
          })
          .toList();

      if (kDebugMode) {
        debugPrint('📦 Loaded ${recipes.length} recipes from community cache');
      }

      return recipes;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading community cache: $e');
      }
      return [];
    }
  }

  /// Clear community cache
  Future<void> clearCommunityCache() async {
    try {
      final box = _communityCacheBoxInstance;
      if (box == null) return;
      
      await box.clear();
      await _metadataBoxInstance?.delete('community_cache_timestamp');
      
      if (kDebugMode) {
        debugPrint('🗑️ Cleared community cache');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error clearing community cache: $e');
      }
    }
  }

  // ==================== Metadata Helpers ====================

  Future<void> _saveMetadata(String key, String value) async {
    try {
      final box = _metadataBoxInstance;
      if (box == null) {
        await initialize();
        return _saveMetadata(key, value);
      }
      await box.put(key, value);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error saving metadata: $e');
      }
    }
  }

  Future<String?> _getMetadata(String key) async {
    try {
      final box = _metadataBoxInstance;
      if (box == null) {
        await initialize();
        return _getMetadata(key);
      }
      return box.get(key) as String?;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error getting metadata: $e');
      }
      return null;
    }
  }

  /// Get last sync timestamp for a given data type
  Future<DateTime?> getLastSyncTime(String dataType) async {
    final timestamp = await _getMetadata('${dataType}_timestamp');
    if (timestamp == null) return null;
    try {
      return DateTime.parse(timestamp);
    } catch (_) {
      return null;
    }
  }

  /// Clear all local storage (useful for logout or reset)
  Future<void> clearAll() async {
    try {
      await _userRecipesBoxInstance?.clear();
      await _collectionsBoxInstance?.clear();
      await _discoverCacheBoxInstance?.clear();
      await _metadataBoxInstance?.clear();
      
      if (kDebugMode) {
        debugPrint('🗑️ Cleared all local storage');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error clearing all storage: $e');
      }
    }
  }
}

