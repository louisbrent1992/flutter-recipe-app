import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../models/api_response.dart';
import '../services/recipe_service.dart';
import '../services/collection_service.dart';
import '../services/game_center_service.dart';
import '../services/local_storage_service.dart';
import '../services/connectivity_service.dart';

class RecipeProvider extends ChangeNotifier {
  // Cross-screen refresh mechanism
  final StreamController<void> _recipesChangedController =
      StreamController<void>.broadcast();
  Stream<void> get onRecipesChanged => _recipesChangedController.stream;

  // AI generated recipes
  List<Recipe> _generatedRecipes = [];
  Recipe? _importedRecipe;
  bool _isLoading = false;
  ApiResponse<Recipe>? _error;

  // User recipes with pagination
  List<Recipe> _userRecipes = [];
  int _currentPage = 1;
  int _totalPages = 1;
  bool _hasNextPage = false;
  bool _hasPrevPage = false;
  int _totalRecipes = 0;
  int _totalUserRecipes = 0; // Dedicated count for user-saved recipes
  int _currentLimit = 10; // Track the current limit for cache invalidation

  // Lightweight in-memory caches to reduce network calls and jank
  // Cache user recipes by page (limit-specific)
  final Map<String, List<Recipe>> _userRecipesCache = {}; // key: "page_limit"
  final Map<String, Map<String, dynamic>> _userPaginationCache =
      {}; // key: "page_limit"

  // Cache generated/external search results by a composite key and page
  // key format: query=<q>|difficulty=<d>|tag=<t>|limit=<l>
  final Map<String, Map<int, List<Recipe>>> _generatedRecipesCache = {};
  final Map<String, Map<int, Map<String, dynamic>>> _generatedPaginationCache =
      {};

  // Session-level discover cache (fetch once, filter client-side)
  List<Recipe> _sessionDiscoverCache = [];
  // Preserve original deterministic order for daily random recipe selection
  // This ensures daily recipe is consistent even if user manually shuffles
  List<Recipe> _sessionDiscoverCacheOriginalOrder = [];
  DateTime? _sessionCacheTime;
  static const int _sessionCacheSize = 500;
  static const Duration _sessionCacheDuration = Duration(hours: 1);

  // Session-level community cache (fetch once, filter client-side)
  List<Recipe> _sessionCommunityCache = [];
  List<Recipe> _communityRecipes =
      []; // Dedicated list for displayed community recipes
  DateTime? _communityCacheTime;
  static const int _communityCacheSize = 200;

  // Favorites removed: no favorites cache

  // Getters
  List<Recipe> get generatedRecipes => _generatedRecipes;
  Recipe? get importedRecipe => _importedRecipe;
  bool get isLoading => _isLoading;
  ApiResponse<Recipe>? get error => _error;
  List<Recipe> get userRecipes => _userRecipes;
  List<Recipe> get communityRecipes => _communityRecipes;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  bool get hasNextPage => _hasNextPage;
  bool get hasPrevPage => _hasPrevPage;
  int get totalRecipes => _totalRecipes;
  int get totalUserRecipes => _totalUserRecipes;

  // Set loading state
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  // Set error message
  void _setError(String? errorMessage) {
    _error = ApiResponse<Recipe>.error(
      errorMessage ?? 'An unexpected error occurred',
    );
    notifyListeners();
  }

  // Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  //----------------------------------------
  // AI RECIPE METHODS
  //----------------------------------------

  // Generate recipes with AI
  Future<void> generateRecipes({
    List<String>? ingredients,
    List<String>? dietaryRestrictions,
    String? cuisineType,
    bool random = false,
  }) async {
    debugPrint('🟡 [Provider] generateRecipes called');
    _setLoading(true);
    clearError();

    try {
      debugPrint('🟡 [Provider] Calling RecipeService.generateRecipes');
      final response = await RecipeService.generateRecipes(
        ingredients: ingredients,
        dietaryRestrictions: dietaryRestrictions,
        cuisineType: cuisineType,
        random: random,
      );
      debugPrint(
        '🟡 [Provider] RecipeService.generateRecipes returned: success=${response.success}',
      );

      if (response.success && response.data != null) {
        _generatedRecipes = response.data ?? [];

        // Unlock first generation achievement
        _unlockFirstGenerationAchievement();

        notifyListeners();
      } else {
        _setError(response.message ?? 'Failed to generate recipes');
        _generatedRecipes = [];
      }
    } catch (e) {
      _setError(e.toString());
      _generatedRecipes = [];
    } finally {
      _setLoading(false);
    }
  }

  // Import recipe from social media URL
  // Returns a Map with 'recipe' and 'fromCache' keys
  Future<Map<String, dynamic>?> importRecipeFromUrl(
    String url,
    BuildContext context,
  ) async {
    debugPrint('🟡 [Provider] importRecipeFromUrl called with: $url');
    _setLoading(true);
    clearError();

    try {
      debugPrint('🟡 [Provider] Calling RecipeService.importRecipeFromUrl');
      final response = await RecipeService.importRecipeFromUrl(url);
      debugPrint(
        '🟡 [Provider] RecipeService.importRecipeFromUrl returned: success=${response.success}',
      );

      if (response.success && response.data != null) {
        final recipe = response.data!;
        final fromCache = response.metadata?['fromCache'] as bool? ?? false;

        // Check for duplicates
        if (isDuplicateRecipe(recipe)) {
          _setError('This recipe is already in your collection');
          if (context.mounted) {
            final duplicateRecipe = findDuplicateRecipe(recipe);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'This recipe is already in your collection',
                ),
                backgroundColor: Colors.orange,
                action:
                    duplicateRecipe != null
                        ? SnackBarAction(
                          label: 'View Recipe',
                          textColor: Colors.white,
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              '/recipeDetail',
                              arguments: duplicateRecipe,
                            );
                          },
                        )
                        : null,
                duration: const Duration(seconds: 6),
              ),
            );
          }
          return null;
        }

        _importedRecipe = recipe;

        // Unlock first import achievement
        _unlockFirstImportAchievement();

        notifyListeners();
        return {'recipe': _importedRecipe, 'fromCache': fromCache};
      } else {
        _setError(response.message ?? 'Failed to import recipe');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Failed to import recipe'),
              backgroundColor: Colors.red,
            ),
          );
        }
        _importedRecipe = null;
        return null;
      }
    } catch (e) {
      _setError(e.toString());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      _importedRecipe = null;
      return null;
    } finally {
      // CRITICAL: Always reset loading state, even if request fails
      _setLoading(false);
    }
  }

  //----------------------------------------
  // USER RECIPE METHODS
  //----------------------------------------

  // Load all user recipes with pagination
  Future<void> loadUserRecipes({
    int page = 1,
    int limit = 10,
    bool forceRefresh = false,
  }) async {
    clearError();

    // If limit changed, clear the cache
    if (limit != _currentLimit) {
      _userRecipesCache.clear();
      _userPaginationCache.clear();
      _currentLimit = limit;
      _totalPages = 0; // Reset to force recalculation
    }

    // Create cache key with page and limit
    final cacheKey = '${page}_$limit';

    // OFFLINE-FIRST: Load from local storage first (for page 1 only)
    // Even on forceRefresh, show local data first, then sync
    bool hasLocalData = false;
    if (page == 1) {
      try {
        final localStorage = LocalStorageService();
        final localRecipes = await localStorage.loadUserRecipes();
        if (localRecipes.isNotEmpty) {
          hasLocalData = true;
          // Show cached data immediately (even on refresh)
          _userRecipes = localRecipes;
          _totalRecipes = localRecipes.length;
          _totalUserRecipes = localRecipes.length;
          _totalPages = (localRecipes.length / limit).ceil();
          _currentPage = 1;
          _hasNextPage = localRecipes.length > limit;
          _hasPrevPage = false;
          notifyListeners();

          // Continue to network fetch in background (will update if successful)
        }
      } catch (e) {
        debugPrint('❌ Error loading user recipes: $e');
      }
    }

    // Serve from in-memory cache if available and not forced
    if (!forceRefresh && _userRecipesCache.containsKey(cacheKey)) {
      final cached = _userRecipesCache[cacheKey];
      _userRecipes = cached != null ? List<Recipe>.from(cached) : <Recipe>[];
      final pagination = _userPaginationCache[cacheKey];
      if (pagination != null) {
        _currentPage = pagination['page'] ?? page;
        _totalPages = pagination['totalPages'] ?? _totalPages;
        _hasNextPage = pagination['hasNextPage'] ?? _hasNextPage;
        _hasPrevPage = pagination['hasPrevPage'] ?? _hasPrevPage;
        _totalRecipes = pagination['total'] ?? _userRecipes.length;
      }
      notifyListeners();
      return;
    }

    // Only set loading if we don't have local data (to avoid hiding cached data)
    if (!hasLocalData) {
      _setLoading(true);
    }

    // Skip network request if we have local data and aren't forcing a refresh.
    // Note: We skip regardless of connectivity status because:
    // 1. connectivity_plus only checks network interface (WiFi/mobile), not actual internet
    // 2. Even if WiFi is connected, the server might not be reachable
    // 3. We want to avoid unnecessary network requests when we have cached data
    if (hasLocalData && !forceRefresh) {
      debugPrint(
        '⚠️ Network sync skipped (has cached data), using cached data',
      );
      _setLoading(false);
      return; // Use cached data, skip network request
    }

    // Also skip if connectivity reports offline and no local data (no point trying)
    // This is a best-effort check - connectivity_plus may report online even if server is unreachable
    final connectivityService = ConnectivityService();
    if (!hasLocalData && !connectivityService.isOnline) {
      debugPrint('⚠️ Network sync skipped (offline, no cached data)');
      _setLoading(false);
      return;
    }

    try {
      final response = await RecipeService.getUserRecipes(
        page: page,
        limit: limit,
      );

      if (response.success && response.data != null) {
        final data = response.data!;

        // Safely handle recipes array
        final recipesList = data['recipes'];
        if (recipesList == null) {
          _userRecipes = [];
          _setError('Unable to load recipes. Please try again.');
          return;
        }

        if (recipesList is! List) {
          _userRecipes = [];
          _setError('Unable to load recipes. Please try again.');
          return;
        }

        _userRecipes = List<Recipe>.from(recipesList as List<Recipe>);

        // Save to local storage (for page 1, save all recipes)
        if (page == 1) {
          try {
            final localStorage = LocalStorageService();
            await localStorage.saveUserRecipes(_userRecipes);
          } catch (e) {
            debugPrint('Error saving to local storage: $e');
          }
        }

        // Cache the page data with limit-aware key
        _userRecipesCache[cacheKey] = List<Recipe>.unmodifiable(_userRecipes);

        // Safely handle pagination data
        final pagination = data['pagination'];

        if (pagination != null && pagination is Map<String, dynamic>) {
          _currentPage = pagination['page'] ?? page;

          // Preserve totalPages if server returns 0 or null but we know better
          final serverTotalPages = pagination['totalPages'];
          if (serverTotalPages != null && serverTotalPages > 0) {
            _totalPages = serverTotalPages;
          } else if (_totalPages == 0 || _totalPages == 1) {
            // If we don't have a good value yet, calculate from total and limit
            final total = pagination['total'] ?? 0;
            if (total > 0) {
              _totalPages = (total / limit).ceil();
            } else {
              _totalPages = 1;
            }
          }
          // Otherwise keep existing _totalPages value

          _hasNextPage = pagination['hasNextPage'] ?? false;
          _hasPrevPage = pagination['hasPrevPage'] ?? (page > 1);
          _totalRecipes = pagination['total'] ?? 0;
          _totalUserRecipes = _totalRecipes; // keep user-specific total in sync

          // Cache pagination per page with limit-aware key
          _userPaginationCache[cacheKey] = {
            'page': _currentPage,
            'totalPages': _totalPages,
            'hasNextPage': _hasNextPage,
            'hasPrevPage': _hasPrevPage,
            'total': _totalRecipes,
          };
        } else {
          // Fallback values if pagination data is missing entirely
          _currentPage = page;
          // Preserve existing totalPages if we have it
          if (_totalPages == 0) {
            _totalPages = 1;
          }
          _hasNextPage = false;
          _hasPrevPage = page > 1;
          _totalRecipes = _userRecipes.length;
          _totalUserRecipes = _userRecipes.length;

          _userPaginationCache[cacheKey] = {
            'page': _currentPage,
            'totalPages': _totalPages,
            'hasNextPage': _hasNextPage,
            'hasPrevPage': _hasPrevPage,
            'total': _totalRecipes,
          };
        }

        notifyListeners();
      } else {
        // Only set error if we don't have local data
        if (!hasLocalData) {
          _setError(response.message ?? 'Failed to load recipes');
          _userRecipes = [];
          _totalUserRecipes = 0;
        } else {
          // If we have local data, just log at debug level
          debugPrint(
            '⚠️ Network sync failed, using cached data: ${response.message}',
          );
          // Ensure we notify listeners to show the cached data
          notifyListeners();
        }
      }
    } catch (e) {
      // Only set error if we don't have local data
      if (!hasLocalData) {
        _setError(e.toString());
        _userRecipes = [];
        _totalUserRecipes = 0;
      } else {
        // If we have local data, just log at debug level
        debugPrint('⚠️ Network sync failed, using cached data: $e');
        // Ensure we notify listeners to show the cached data
        notifyListeners();
      }
    } finally {
      // Only set loading to false if we set it to true
      if (!hasLocalData) {
        _setLoading(false);
      }
    }
  }

  // Load next page of recipes
  Future<void> loadNextPage() async {
    if (_hasNextPage) {
      await loadUserRecipes(page: _currentPage + 1);
    }
  }

  // Load previous page of recipes
  Future<void> loadPrevPage() async {
    if (_hasPrevPage) {
      await loadUserRecipes(page: _currentPage - 1);
    }
  }

  // Get a specific user recipe
  Future<Recipe?> getUserRecipe(String id) async {
    _setLoading(true);
    clearError();

    try {
      final response = await RecipeService.getUserRecipe(id);

      if (response.success && response.data != null) {
        return response.data;
      } else {
        _setError(response.message ?? 'Failed to get recipe');
        return null;
      }
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Create a new user recipe
  Future<Recipe?> createUserRecipe(
    Recipe recipe,
    BuildContext context, {
    String? originalRecipeId,
    bool refreshCollections = true, // Set to false to skip collection refresh
  }) async {
    // Check for duplicates before attempting to save
    if (isDuplicateRecipe(recipe)) {
      _setError('This recipe already exists in your collection');
      if (context.mounted) {
        final duplicateRecipe = findDuplicateRecipe(recipe);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'This recipe already exists in your collection',
            ),
            backgroundColor: Colors.orange,
            action:
                duplicateRecipe != null
                    ? SnackBarAction(
                      label: 'View Recipe',
                      textColor: Colors.white,
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/recipeDetail',
                          arguments: duplicateRecipe,
                        );
                      },
                    )
                    : null,
            duration: const Duration(seconds: 6),
          ),
        );
      }
      return null;
    }

    // OPTIMISTIC UPDATE: Save locally first (works offline)
    final tempId =
        recipe.id.isEmpty
            ? 'temp_${DateTime.now().millisecondsSinceEpoch}'
            : recipe.id;
    final optimisticRecipe = recipe.copyWith(id: tempId);

    // Add to local list immediately
    _userRecipes.add(optimisticRecipe);
    _totalUserRecipes = (_totalUserRecipes + 1).clamp(0, 1 << 31);

    // Save to local storage immediately
    try {
      final localStorage = LocalStorageService();
      await localStorage.saveUserRecipe(optimisticRecipe);
    } catch (e) {
      debugPrint('Error saving recipe to local storage: $e');
    }

    // Notify UI immediately (notifyListeners triggers Consumer rebuilds)
    // Note: emitRecipesChanged is called after server sync to avoid duplicate fetches
    notifyListeners();

    // Show success message
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recipe saved! Syncing...'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }

    // Try server sync in background (non-blocking)
    _setLoading(true);
    clearError();

    try {
      final response = await RecipeService.createUserRecipe(
        recipe,
        originalRecipeId: originalRecipeId,
      );

      if (context.mounted) {
        // Handle duplicate error from server (409 status code)
        if (response.statusCode == 409) {
          _setError(
            response.message ?? 'This recipe already exists in your collection',
          );
          // Try to find the duplicate recipe to show "View Recipe" action
          final duplicateRecipe = findDuplicateRecipe(recipe);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response.message ??
                    'This recipe already exists in your collection',
              ),
              backgroundColor: Colors.orange,
              action:
                  duplicateRecipe != null
                      ? SnackBarAction(
                        label: 'View Recipe',
                        textColor: Colors.white,
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/recipeDetail',
                            arguments: duplicateRecipe,
                          );
                        },
                      )
                      : null,
              duration: const Duration(seconds: 6),
            ),
          );
          return null;
        }

        final collectionService = context.read<CollectionService>();

        if (response.success && response.data != null) {
          final serverRecipe = response.data!;

          // Replace optimistic recipe with server version (has real ID)
          final index = _userRecipes.indexWhere((r) => r.id == tempId);
          if (index != -1) {
            _userRecipes[index] = serverRecipe;
          } else {
            // If not found, just add it
            _userRecipes.add(serverRecipe);
          }

          // Save server version to local storage
          try {
            final localStorage = LocalStorageService();
            await localStorage.saveUserRecipe(serverRecipe);
          } catch (e) {
            debugPrint('Error saving server recipe to local storage: $e');
          }

          // Force refresh collections to update recently added (only if requested)
          if (refreshCollections) {
          await collectionService.getCollections(forceRefresh: true);
          }

          // Sync with Game Center for achievements
          _syncGameCenter();

          notifyListeners();
          emitRecipesChanged();

          if (context.mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Recipe synced!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }

          return serverRecipe;
        } else {
          // Server failed but we already saved locally
          if (context.mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Recipe saved locally. Will sync when online.',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          // Return the optimistic recipe (already in list)
          return optimisticRecipe;
        }
      } else {
        // Server failed but we already saved locally
        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Recipe saved locally. Will sync when online.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return optimisticRecipe;
      }
    } catch (e) {
      // Network error - recipe already saved locally
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Recipe saved locally. Will sync when online.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return optimisticRecipe;
    } finally {
      _setLoading(false);
    }
  }

  // Update an existing user recipe
  Future<Recipe?> updateUserRecipe(Recipe recipe) async {
    _setLoading(true);
    clearError();

    try {
      final response = await RecipeService.updateUserRecipe(recipe);

      if (response.success && response.data != null) {
        final updatedRecipe = response.data;

        // Update in list
        final index = _userRecipes.indexWhere((r) => r.id == recipe.id);
        if (index != -1) {
          _userRecipes[index] = updatedRecipe!;
        }

        // Save to local storage
        try {
          final localStorage = LocalStorageService();
          await localStorage.saveUserRecipe(updatedRecipe!);
        } catch (e) {
          debugPrint('Error saving updated recipe to local storage: $e');
        }

        // Favorites removed

        notifyListeners();
        emitRecipesChanged();
        return updatedRecipe;
      } else {
        _setError(response.message ?? 'Failed to update recipe');
        return null;
      }
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Delete a user recipe
  Future<bool> deleteUserRecipe(
    String id,
    BuildContext context, {
    bool refreshCollections = true, // Set to false to skip collection refresh
  }) async {
    _setLoading(true);
    clearError();

    try {
      final response = await RecipeService.deleteUserRecipe(id);

      if (context.mounted) {
        final collectionService = context.read<CollectionService>();

        if (response.success) {
          // Remove from all local lists
          _userRecipes.removeWhere((recipe) => recipe.id == id);
          _generatedRecipes.removeWhere((recipe) => recipe.id == id);

          // Clear imported recipe if it matches
          if (_importedRecipe?.id == id) {
            _importedRecipe = null;
          }

          // Remove from local storage
          try {
            final localStorage = LocalStorageService();
            await localStorage.deleteUserRecipe(id);
          } catch (e) {
            debugPrint('Error deleting recipe from local storage: $e');
          }

          // Refresh collections to ensure the deleted recipe is removed from all collections (only if requested)
          if (refreshCollections) {
          await collectionService.refreshCollectionsAfterRecipeDeletion(id);
          }

          // Update user recipes total optimistically
          _totalUserRecipes = (_totalUserRecipes - 1).clamp(0, 1 << 31);
          notifyListeners();
          emitRecipesChanged();
          return true;
        } else {
          _setError(response.message ?? 'Failed to delete recipe');
          return false;
        }
      }
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
    return false;
  }

  // Favorites removed: toggleFavorite no longer supported

  // Favorites removed: no favorite recipes loader

  // Deprecated: kept for reference during refactor
  // Favorite flags are now applied from cached ids via _applyFavoriteFlagsFromCache()

  // Refresh all data
  Future<void> refreshAll() async {
    await loadUserRecipes();
  }

  // Check if a recipe is a duplicate
  bool isDuplicateRecipe(Recipe recipe) {
    // Check if recipe with same source URL exists
    if (recipe.sourceUrl != null) {
      return _userRecipes.any((r) => r.sourceUrl == recipe.sourceUrl);
    }

    // If no source URL, check title and description
    return _userRecipes.any(
      (r) =>
          r.title.toLowerCase() == recipe.title.toLowerCase() &&
          r.description.toLowerCase() == recipe.description.toLowerCase(),
    );
  }

  // Find the duplicate recipe in user's collection
  Recipe? findDuplicateRecipe(Recipe recipe) {
    // Check if recipe with same source URL exists
    if (recipe.sourceUrl != null) {
      return _userRecipes.firstWhere(
        (r) => r.sourceUrl == recipe.sourceUrl,
        orElse: () => Recipe(),
      );
    }

    // If no source URL, check title and description
    final foundRecipe = _userRecipes.firstWhere(
      (r) =>
          r.title.toLowerCase() == recipe.title.toLowerCase() &&
          r.description.toLowerCase() == recipe.description.toLowerCase(),
      orElse: () => Recipe(),
    );

    return foundRecipe.id.isNotEmpty ? foundRecipe : null;
  }

  //----------------------------------------
  // API SEARCH METHODS
  //----------------------------------------

  // Fetch session-level discover cache (500 recipes, reused for filtering)
  Future<void> fetchSessionDiscoverCache({bool forceRefresh = false}) async {
    // Check if cache is still valid
    if (!forceRefresh &&
        _sessionDiscoverCache.isNotEmpty &&
        _sessionCacheTime != null &&
        DateTime.now().difference(_sessionCacheTime!) < _sessionCacheDuration) {
      return; // Use existing cache
    }

    // OFFLINE-FIRST: Load from local storage first (even on forceRefresh)
    bool hasLocalCache = false;
    try {
      final localStorage = LocalStorageService();
      final localCache = await localStorage.loadDiscoverCache();
      if (localCache.isNotEmpty) {
        hasLocalCache = true;
        _sessionDiscoverCache = localCache;
        // Preserve original order from local cache (should already be deterministically shuffled)
        _sessionDiscoverCacheOriginalOrder = List<Recipe>.from(localCache);
        _sessionCacheTime = DateTime.now();
        notifyListeners();
        // Continue to network fetch in background
      }
    } catch (e) {
      debugPrint('Error loading discover cache from local storage: $e');
    }

    clearError();
    // Only set loading if we don't have local cache (to avoid hiding cached data)
    if (!hasLocalCache) {
      _setLoading(true);
    }

    try {
      final response = await RecipeService.searchExternalRecipes(
        limit: _sessionCacheSize,
        random: true,
      );

      if (response.success && response.data != null) {
        final data = response.data!;
        final recipesList = data['recipes'];

        if (recipesList != null && recipesList is List) {
          _sessionDiscoverCache =
              recipesList
                  .map((item) => Recipe.fromJson(item as Map<String, dynamic>))
                  .toList();

          // Use deterministic shuffle based on date for consistent daily random recipe selection
          // This ensures the same shuffle order throughout the day, but different each day
          final now = DateTime.now();
          final start = DateTime(now.year, 1, 1);
          final dayOfYear = now.difference(start).inDays + 1;
          final seed = now.year * 365 + dayOfYear;
          _sessionDiscoverCache.shuffle(Random(seed));

          // Preserve original deterministic order for daily recipe selection
          // This ensures daily recipe is consistent even if user manually shuffles
          _sessionDiscoverCacheOriginalOrder = List<Recipe>.from(
            _sessionDiscoverCache,
          );

          _sessionCacheTime = DateTime.now();

          // Save to local storage
          try {
            final localStorage = LocalStorageService();
            await localStorage.saveDiscoverCache(_sessionDiscoverCache);
          } catch (e) {
            debugPrint('Error saving discover cache to local storage: $e');
          }
        }
      } else {
        // Only set error if we don't have local cache
        if (!hasLocalCache) {
          _setError(response.message ?? 'Failed to fetch discover recipes');
        } else {
          debugPrint(
            '⚠️ Network sync failed, using cached discover recipes: ${response.message}',
          );
          // Ensure we notify listeners to show the cached data
          notifyListeners();
        }
      }
    } catch (e) {
      // Only set error if we don't have local cache
      if (!hasLocalCache) {
        debugPrint('❌ Error fetching session cache: $e');
        _setError('Failed to load recipes: $e');
      } else {
        debugPrint('⚠️ Network sync failed, using cached discover recipes: $e');
        // Ensure we notify listeners to show the cached data
        notifyListeners();
      }
    } finally {
      // Only set loading to false if we set it to true
      if (!hasLocalCache) {
        _setLoading(false);
      }
    }
  }

  // Get filtered and paginated recipes from session cache
  List<Recipe> getFilteredDiscoverRecipes({
    String? query,
    String? difficulty,
    String? tag,
    int page = 1,
    int limit = 12,
  }) {
    // If session cache is empty, try to preserve current generated recipes
    // This prevents clearing the list when cache is temporarily unavailable
    if (_sessionDiscoverCache.isEmpty) {
      // If we have generated recipes already displayed, return them to preserve UI
      // This can happen during cache refresh or when offline
      if (_generatedRecipes.isNotEmpty) {
        return _generatedRecipes;
      }
      return [];
    }

    // Start with all recipes from session cache
    var filtered = List<Recipe>.from(_sessionDiscoverCache);

    // Apply difficulty filter
    if (difficulty != null && difficulty != 'All') {
      filtered =
          filtered
              .where(
                (r) => r.difficulty.toLowerCase() == difficulty.toLowerCase(),
              )
              .toList();
    }

    // Apply tag filter - split by comma and search each tag individually (OR logic)
    if (tag != null && tag != 'All') {
      // Split by comma and treat each as individual search term
      final tagList =
          tag
              .split(',')
              .map((t) => t.trim().toLowerCase())
              .where((t) => t.isNotEmpty)
              .toList();

      if (tagList.isEmpty) {
        return [];
      }

      // Match recipes where ANY recipe tag matches ANY filter tag (OR logic - cumulative results)
      filtered =
          filtered.where((r) {
            final recipeTagsLower =
                r.tags.map((t) => t.trim().toLowerCase()).toList();
            // Check if any recipe tag matches any filter tag
            return tagList.any(
              (filterTag) => recipeTagsLower.any((recipeTag) {
                // Normalize both tags (remove extra spaces, special chars)
                final normalizedRecipe =
                    recipeTag.replaceAll(RegExp(r'[^\w\s]'), '').trim();
                final normalizedFilter =
                    filterTag.replaceAll(RegExp(r'[^\w\s]'), '').trim();

                // Exact match
                if (normalizedRecipe == normalizedFilter) return true;

                // Stem matching (handles "holiday" vs "holidays", "fall" vs "falls")
                final recipeStem = normalizedRecipe.replaceAll(
                  RegExp(r's$'),
                  '',
                );
                final filterStem = normalizedFilter.replaceAll(
                  RegExp(r's$'),
                  '',
                );
                if (recipeStem == filterStem && recipeStem.isNotEmpty) {
                  return true;
                }

                // Word boundary matching (handles multi-word tags)
                final recipeWords = normalizedRecipe.split(RegExp(r'[\s\-_]+'));
                final filterWords = normalizedFilter.split(RegExp(r'[\s\-_]+'));
                if (recipeWords.any((w) => filterWords.contains(w)) ||
                    filterWords.any((w) => recipeWords.contains(w))) {
                  return true;
                }

                // Contains match (fallback) - more lenient
                if (normalizedRecipe.contains(normalizedFilter) ||
                    normalizedFilter.contains(normalizedRecipe)) {
                  return true;
                }

                return false;
              }),
            );
          }).toList();
    }

    // Apply text search filter (if query provided) - split by comma for OR logic
    if (query != null && query.isNotEmpty) {
      // Split by comma and treat each as individual search term (OR logic)
      final queryTerms =
          query
              .split(',')
              .map((t) => t.trim().toLowerCase())
              .where((t) => t.isNotEmpty)
              .toList();

      if (queryTerms.isNotEmpty) {
        // Match recipes where ANY term appears in title, description, or tags (OR logic)
        filtered =
            filtered.where((r) {
              final titleLower = r.title.toLowerCase();
              final descLower = r.description.toLowerCase();
              final tagsLower = r.tags.map((t) => t.toLowerCase()).toList();

              // Check if ANY query term matches ANY field
              return queryTerms.any(
                (term) =>
                    titleLower.contains(term) ||
                    descLower.contains(term) ||
                    tagsLower.any((tag) => tag.contains(term)),
              );
            }).toList();
      }
    }

    // Calculate pagination
    final total = filtered.length;
    final totalPages = (total / limit).ceil();
    final startIndex = (page - 1) * limit;
    final endIndex = (startIndex + limit).clamp(0, total);

    // Update pagination state
    _currentPage = page;
    _totalPages = totalPages > 0 ? totalPages : 1;
    _hasNextPage = page < totalPages;
    _hasPrevPage = page > 1;
    _totalRecipes = total;

    // Return paginated subset
    if (startIndex >= total) {
      return [];
    }

    return filtered.sublist(startIndex, endIndex);
  }

  // Randomize the session cache for display purposes
  // This does NOT affect the daily random recipe selection, which uses the original order
  void randomizeSessionCache() {
    if (_sessionDiscoverCache.isNotEmpty) {
      _sessionDiscoverCache.shuffle();
      // Note: We don't update _sessionDiscoverCacheOriginalOrder
      // This ensures daily recipe selection remains consistent
      notifyListeners();
    }
  }

  // Clear session cache (force refresh)
  void clearSessionCache() {
    _sessionDiscoverCache.clear();
    _sessionDiscoverCacheOriginalOrder.clear();
    _sessionCacheTime = null;
  }

  // Get a daily random recipe from discover cache if available
  // Uses date-based seeding to ensure same recipe throughout the day
  // Uses original deterministic order, not the potentially shuffled cache
  Recipe? getDailyRandomRecipeFromCache() {
    // Use original order if available, fallback to current cache if not
    final cacheToUse =
        _sessionDiscoverCacheOriginalOrder.isNotEmpty
            ? _sessionDiscoverCacheOriginalOrder
            : _sessionDiscoverCache;

    if (cacheToUse.isEmpty) {
      return null;
    }

    // Calculate day of year (1-365/366) for deterministic daily selection
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final dayOfYear = now.difference(start).inDays + 1;

    // Create deterministic index based on year and day of year
    // This ensures same recipe for same day, different each day
    final dailyIndex = (now.year * 365 + dayOfYear) % cacheToUse.length;
    return cacheToUse[dailyIndex];
  }

  // Set generated recipes from cache (internal helper)
  void setGeneratedRecipesFromCache(List<Recipe> recipes) {
    _generatedRecipes = recipes;
    notifyListeners();
  }

  // Set community recipes from cache (internal helper)
  void setCommunityRecipesFromCache(List<Recipe> recipes) {
    _communityRecipes = List<Recipe>.from(recipes);
    notifyListeners();
  }

  /// Update the save count for a community recipe
  /// [recipeId] - The ID of the recipe to update
  /// [delta] - The amount to change (positive to increment, negative to decrement)
  void updateCommunityRecipeSaveCount(String recipeId, int delta) {
    // Update session cache
    final cacheIndex = _sessionCommunityCache.indexWhere(
      (r) => r.id == recipeId,
    );
    if (cacheIndex != -1) {
      final currentCount = _sessionCommunityCache[cacheIndex].saveCount;
      _sessionCommunityCache[cacheIndex] = _sessionCommunityCache[cacheIndex]
          .copyWith(saveCount: (currentCount + delta).clamp(0, 1 << 30));
    }

    // Update displayed list
    final displayIndex = _communityRecipes.indexWhere((r) => r.id == recipeId);
    if (displayIndex != -1) {
      final currentCount = _communityRecipes[displayIndex].saveCount;
      _communityRecipes[displayIndex] = _communityRecipes[displayIndex]
          .copyWith(saveCount: (currentCount + delta).clamp(0, 1 << 30));
    }

    notifyListeners();
  }

  // Fetch session-level community cache (200 recipes, reused for filtering)
  Future<void> fetchSessionCommunityCache({bool forceRefresh = false}) async {
    // Check if cache is still valid
    final hasValidCache =
        _sessionCommunityCache.isNotEmpty &&
        _communityCacheTime != null &&
        DateTime.now().difference(_communityCacheTime!) <
            _sessionCacheDuration &&
        !forceRefresh;

    if (hasValidCache) {
      return;
    }

    // Try to load from local storage first (future enhancement)
    bool hasLocalCache = false;
    // Note: We could add a loadCommunityCache method, but for now we'll just fetch from network

    clearError();
    if (!hasLocalCache) {
      _setLoading(true);
    }

    try {
      final response = await RecipeService.getCommunityRecipes(
        limit: _communityCacheSize,
        random: true,
      );

      if (response.success && response.data != null) {
        final data = response.data!;
        final recipesList = data['recipes'];

        if (recipesList != null && recipesList is List) {
          _sessionCommunityCache =
              recipesList
                  .map((item) => Recipe.fromJson(item as Map<String, dynamic>))
                  .toList();

          // Use deterministic shuffle based on date
          final now = DateTime.now();
          final start = DateTime(now.year, 1, 1);
          final dayOfYear = now.difference(start).inDays + 1;
          final seed = now.year * 365 + dayOfYear;
          _sessionCommunityCache.shuffle(Random(seed));

          // Also populate the display list for home screen carousel
          _communityRecipes = List<Recipe>.from(_sessionCommunityCache);

          _communityCacheTime = DateTime.now();
          notifyListeners();
        }
      } else {
        if (!hasLocalCache) {
          _setError(response.message ?? 'Failed to fetch community recipes');
        }
      }
    } catch (e) {
      if (!hasLocalCache) {
        debugPrint('❌ Error fetching community cache: $e');
        _setError('Failed to load community recipes: $e');
      }
    } finally {
      if (!hasLocalCache) {
        _setLoading(false);
      }
    }
  }

  // Fetch community recipes (with filtering)
  Future<void> fetchCommunityRecipes({
    String? query,
    String? difficulty,
    String? tag,
    int page = 1,
    int limit = 12,
    bool forceRefresh = false,
  }) async {
    // Ensure session cache is populated
    await fetchSessionCommunityCache(forceRefresh: forceRefresh);

    // Filter the cached recipes
    final filtered = getFilteredCommunityRecipes(
      query: query,
      difficulty: difficulty,
      tag: tag,
      page: page,
      limit: limit,
    );

    setCommunityRecipesFromCache(filtered);
  }

  // Get filtered and paginated community recipes from session cache
  List<Recipe> getFilteredCommunityRecipes({
    String? query,
    String? difficulty,
    String? tag,
    int page = 1,
    int limit = 12,
  }) {
    if (_sessionCommunityCache.isEmpty) {
      if (_generatedRecipes.isNotEmpty) {
        return _generatedRecipes;
      }
      return [];
    }

    var filtered = List<Recipe>.from(_sessionCommunityCache);

    // Apply difficulty filter
    if (difficulty != null && difficulty != 'All') {
      filtered =
          filtered
              .where(
                (r) => r.difficulty.toLowerCase() == difficulty.toLowerCase(),
              )
              .toList();
    }

    // Apply tag filter
    if (tag != null && tag != 'All') {
      final tagList =
          tag
              .split(',')
              .map((t) => t.trim().toLowerCase())
              .where((t) => t.isNotEmpty)
              .toList();

      if (tagList.isEmpty) {
        return [];
      }

      filtered =
          filtered.where((r) {
            final recipeTagsLower =
                r.tags.map((t) => t.trim().toLowerCase()).toList();
            return tagList.any(
              (filterTag) => recipeTagsLower.any((recipeTag) {
                final normalizedRecipe =
                    recipeTag.replaceAll(RegExp(r'[^\w\s]'), '').trim();
                final normalizedFilter =
                    filterTag.replaceAll(RegExp(r'[^\w\s]'), '').trim();
                if (normalizedRecipe == normalizedFilter) return true;
                final recipeStem = normalizedRecipe.replaceAll(
                  RegExp(r's$'),
                  '',
                );
                final filterStem = normalizedFilter.replaceAll(
                  RegExp(r's$'),
                  '',
                );
                if (recipeStem == filterStem && recipeStem.isNotEmpty) {
                  return true;
                }
                final recipeWords = normalizedRecipe.split(RegExp(r'[\s\-_]+'));
                final filterWords = normalizedFilter.split(RegExp(r'[\s\-_]+'));
                if (recipeWords.any((w) => filterWords.contains(w)) ||
                    filterWords.any((w) => recipeWords.contains(w))) {
                  return true;
                }
                if (normalizedRecipe.contains(normalizedFilter) ||
                    normalizedFilter.contains(normalizedRecipe)) {
                  return true;
                }
                return false;
              }),
            );
          }).toList();
    }

    // Apply text search filter
    if (query != null && query.isNotEmpty) {
      final queryTerms =
          query
              .split(',')
              .map((t) => t.trim().toLowerCase())
              .where((t) => t.isNotEmpty)
              .toList();

      if (queryTerms.isNotEmpty) {
        filtered =
            filtered.where((r) {
              final searchableText =
                  '${r.title} ${r.description} ${r.tags.join(' ')}'
                      .toLowerCase();
              return queryTerms.any((term) => searchableText.contains(term));
            }).toList();
      }
    }

    // Calculate pagination
    final total = filtered.length;
    final totalPages = (total / limit).ceil();
    final startIndex = (page - 1) * limit;
    final endIndex = (startIndex + limit).clamp(0, total);

    _currentPage = page;
    _totalPages = totalPages > 0 ? totalPages : 1;
    _hasNextPage = page < totalPages;
    _hasPrevPage = page > 1;
    _totalRecipes = total;

    if (startIndex >= total) {
      return [];
    }

    return filtered.sublist(startIndex, endIndex);
  }

  // Search for recipes from external API
  Future<void> searchExternalRecipes({
    String? query,
    String? difficulty,
    String? tag,
    int page = 1,
    int limit = 10,
    bool forceRefresh = false,
    bool random = false,
  }) async {
    clearError();

    // Build a stable cache key for query+filters+limit+random
    final String cacheKey = _buildSearchKey(
      query: query,
      difficulty: difficulty,
      tag: tag,
      limit: limit,
      random: random,
    );

    // Preserve current recipes to avoid clearing discover screen
    // The discover screen uses _generatedRecipes, so we shouldn't clear it
    // unless we're explicitly refreshing for this specific search
    final currentRecipes = List<Recipe>.from(_generatedRecipes);

    // Serve from cache if available
    if (!forceRefresh &&
        _generatedRecipesCache[cacheKey] != null &&
        _generatedRecipesCache[cacheKey]![page] != null) {
      _generatedRecipes = List<Recipe>.from(
        _generatedRecipesCache[cacheKey]![page]!,
      );
      final pagination = _generatedPaginationCache[cacheKey]?[page];
      if (pagination != null) {
        _currentPage = pagination['page'] ?? page;
        _totalPages = pagination['totalPages'] ?? _totalPages;
        _hasNextPage = pagination['hasNextPage'] ?? _hasNextPage;
        _hasPrevPage = pagination['hasPrevPage'] ?? _hasPrevPage;
        _totalRecipes = pagination['total'] ?? _generatedRecipes.length;
      }
      notifyListeners();
      return;
    }

    _setLoading(true);

    try {
      final response = await RecipeService.searchExternalRecipes(
        query: query,
        difficulty: difficulty,
        tag: tag,
        page: page,
        limit: limit,
        random: random,
      );

      if (response.success && response.data != null) {
        final data = response.data!;

        // Safely handle recipes array with null checking
        final recipesList = data['recipes'];
        if (recipesList == null) {
          _generatedRecipes = [];
          _setError('Unable to load recipes. Please try again.');
          return;
        }

        if (recipesList is! List) {
          _generatedRecipes = [];
          _setError('Unable to load recipes. Please try again.');
          return;
        }

        final recipes =
            recipesList
                .map((item) => Recipe.fromJson(item as Map<String, dynamic>))
                .toList();

        // Store both the generated recipes and the original set
        _generatedRecipes = recipes;

        // Cache the page results
        _generatedRecipesCache.putIfAbsent(
          cacheKey,
          () => <int, List<Recipe>>{},
        );
        _generatedRecipesCache[cacheKey]![page] = List<Recipe>.unmodifiable(
          recipes,
        );

        // Safely handle pagination data
        final pagination = data['pagination'];
        if (pagination != null && pagination is Map<String, dynamic>) {
          _currentPage = pagination['page'] ?? page;

          // Validate pagination against actual results
          // If we got fewer results than the limit, or no results on page > 1,
          // adjust the total pages accordingly
          final actualResultsCount = recipes.length;
          final serverTotalPages = pagination['totalPages'] ?? 1;

          // If we're on page 1 and got fewer results than the limit, there's only 1 page
          if (page == 1 && actualResultsCount < limit) {
            _totalPages = 1;
            _hasNextPage = false;
          }
          // If we're on page > 1 and got 0 results, adjust totalPages to previous page
          else if (page > 1 && actualResultsCount == 0) {
            _totalPages = page - 1;
            _hasNextPage = false;
            // If we're now beyond the actual total pages, go back to page 1
            if (_currentPage > _totalPages) {
              _currentPage = _totalPages;
            }
          }
          // Otherwise, use server's pagination but validate it makes sense
          else {
            _totalPages = serverTotalPages;
            // Ensure totalPages is at least 1
            if (_totalPages < 1) {
              _totalPages = 1;
            }
            // If we got a full page of results, trust the server's hasNextPage
            // Otherwise, if we got fewer results, there's no next page
            if (actualResultsCount < limit) {
              _hasNextPage = false;
            } else {
              _hasNextPage = pagination['hasNextPage'] ?? false;
            }
          }

          _hasPrevPage = pagination['hasPrevPage'] ?? (page > 1);
          _totalRecipes = pagination['total'] ?? actualResultsCount;

          // Ensure hasNextPage is false if we're on the last page
          if (_currentPage >= _totalPages) {
            _hasNextPage = false;
          }

          // Ensure hasPrevPage is false if we're on page 1
          if (_currentPage <= 1) {
            _hasPrevPage = false;
          }

          _generatedPaginationCache.putIfAbsent(
            cacheKey,
            () => <int, Map<String, dynamic>>{},
          );
          _generatedPaginationCache[cacheKey]![page] = {
            'page': _currentPage,
            'totalPages': _totalPages,
            'hasNextPage': _hasNextPage,
            'hasPrevPage': _hasPrevPage,
            'total': _totalRecipes,
          };
        } else {
          // Fallback values if pagination data is missing
          // Calculate pagination based on actual results
          _currentPage = page;

          // If we got fewer results than the limit, there's only 1 page
          if (recipes.length < limit) {
            _totalPages = 1;
            _hasNextPage = false;
          } else {
            // Estimate total pages from results (this is a fallback, server should provide this)
            _totalPages = 1; // Default to 1 if we can't determine
            _hasNextPage = false; // Can't know for sure without server data
          }

          _hasPrevPage = page > 1;
          _totalRecipes = recipes.length;

          _generatedPaginationCache.putIfAbsent(
            cacheKey,
            () => <int, Map<String, dynamic>>{},
          );
          _generatedPaginationCache[cacheKey]![page] = {
            'page': _currentPage,
            'totalPages': _totalPages,
            'hasNextPage': _hasNextPage,
            'hasPrevPage': _hasPrevPage,
            'total': _totalRecipes,
          };
        }

        notifyListeners();
      } else {
        _setError(response.message ?? 'Failed to search recipes');
        // Don't clear _generatedRecipes on error - preserve current recipes
        // This prevents clearing the discover screen when home screen refresh fails
        // Only clear if we had no recipes to begin with
        if (currentRecipes.isEmpty) {
          _generatedRecipes = [];
        }
      }
    } catch (e) {
      _setError(e.toString());
      // Don't clear _generatedRecipes on error - preserve current recipes
      // This prevents clearing the discover screen when home screen refresh fails
      // Only clear if we had no recipes to begin with
      if (currentRecipes.isEmpty) {
        _generatedRecipes = [];
      }
    } finally {
      _setLoading(false);
    }
  }

  String _buildSearchKey({
    String? query,
    String? difficulty,
    String? tag,
    int? limit,
    bool? random,
  }) {
    final q = (query ?? '').trim().toLowerCase();
    final d = (difficulty ?? 'All').trim();
    final t = (tag ?? 'All').trim();
    final l = (limit ?? 10).toString();
    final r = (random ?? false).toString();
    return 'query=$q|difficulty=$d|tag=$t|limit=$l|random=$r';
  }

  // Emit cross-screen refresh event
  void emitRecipesChanged() {
    _recipesChangedController.add(null);
  }

  /// Sync chef ranking with Game Center
  Future<void> _syncGameCenter() async {
    try {
      final gameCenter = GameCenterService();
      if (!gameCenter.isAuthenticated) {
        await gameCenter.initialize();
      }

      // Calculate chef ranking (similar to nav_drawer logic)
      int stars = 1;
      final recipeCount = _totalUserRecipes;

      // Calculate stars based on recipe count thresholds
      // Updated to match achievement requirements
      if (recipeCount >= 500) {
        stars = 5; // Master Chef
      } else if (recipeCount >= 300) {
        stars = 4; // Executive Chef
      } else if (recipeCount >= 150) {
        stars = 3; // Sous Chef
      } else if (recipeCount >= 50) {
        stars = 2; // Line Cook
      } else {
        stars = 1; // Commis Chef
      }

      // Sync with Game Center
      await gameCenter.syncChefRanking(stars: stars, recipeCount: recipeCount);
    } catch (e) {
      // Silently fail - Game Center is optional
      debugPrint('Game Center sync failed: $e');
    }
  }

  /// Unlock first generation achievement
  Future<void> _unlockFirstGenerationAchievement() async {
    try {
      final gameCenter = GameCenterService();
      if (!gameCenter.isAuthenticated) {
        await gameCenter.initialize();
      }
      if (gameCenter.isAuthenticated) {
        await gameCenter.unlockFirstGeneration();
      }
    } catch (e) {
      debugPrint('Game Center achievement unlock failed: $e');
    }
  }

  /// Unlock first import achievement
  Future<void> _unlockFirstImportAchievement() async {
    try {
      final gameCenter = GameCenterService();
      if (!gameCenter.isAuthenticated) {
        await gameCenter.initialize();
      }
      if (gameCenter.isAuthenticated) {
        await gameCenter.unlockFirstImport();
      }
    } catch (e) {
      debugPrint('Game Center achievement unlock failed: $e');
    }
  }

  /// Like or unlike a community recipe
  Future<bool> toggleRecipeLike(String recipeId, BuildContext context) async {
    clearError();
    _setLoading(true);

    try {
      final response = await RecipeService.toggleRecipeLike(recipeId);

      if (response.success && response.data != null) {
        final data = response.data!;
        final liked = data['liked'] as bool? ?? false;
        final likeCount = data['likeCount'] as int? ?? 0;

        // Update the recipe in community recipes cache
        final index = _sessionCommunityCache.indexWhere(
          (r) => r.id == recipeId,
        );
        if (index != -1) {
          _sessionCommunityCache[index] = _sessionCommunityCache[index]
              .copyWith(isLiked: liked, likeCount: likeCount);
        }

        // Update displayed community recipes
        final displayIndex = _communityRecipes.indexWhere(
          (r) => r.id == recipeId,
        );
        if (displayIndex != -1) {
          _communityRecipes[displayIndex] = _communityRecipes[displayIndex]
              .copyWith(isLiked: liked, likeCount: likeCount);
        }

        notifyListeners();
        emitRecipesChanged();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(liked ? 'Recipe liked!' : 'Recipe unliked'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        return true;
      } else {
        _setError(response.message ?? 'Failed to update like status');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Failed to update like status'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }
    } catch (e) {
      _setError('Failed to update like status: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  @override
  void dispose() {
    _recipesChangedController.close();
    super.dispose();
  }

  // Favorites removed: no favorite cache or flags
}
