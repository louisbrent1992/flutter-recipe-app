import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../models/api_response.dart';
import '../services/recipe_service.dart';
import '../services/collection_service.dart';
import '../services/game_center_service.dart';

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
  DateTime? _sessionCacheTime;
  static const int _sessionCacheSize = 500;
  static const Duration _sessionCacheDuration = Duration(hours: 1);

  // Favorites removed: no favorites cache

  // Getters
  List<Recipe> get generatedRecipes => _generatedRecipes;
  Recipe? get importedRecipe => _importedRecipe;
  bool get isLoading => _isLoading;
  ApiResponse<Recipe>? get error => _error;
  List<Recipe> get userRecipes => _userRecipes;
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

    // Serve from cache if available and not forced
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

    _setLoading(true);

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
          _setError('No recipes data received from server');
          return;
        }

        if (recipesList is! List) {
          _userRecipes = [];
          _setError('Invalid recipes data format received from server');
          return;
        }

        _userRecipes = List<Recipe>.from(recipesList as List<Recipe>);

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
        _setError(response.message ?? 'Failed to load recipes');
        _userRecipes = [];
        _totalUserRecipes = 0;
      }
    } catch (e) {
      _setError(e.toString());
      _userRecipes = [];
      _totalUserRecipes = 0;
    } finally {
      _setLoading(false);
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
  Future<Recipe?> createUserRecipe(Recipe recipe, BuildContext context) async {
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

    _setLoading(true);
    clearError();

    try {
      final response = await RecipeService.createUserRecipe(recipe);

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
          final newRecipe = response.data;
          _userRecipes.add(newRecipe!);
          // Update user recipes total optimistically
          _totalUserRecipes = (_totalUserRecipes + 1).clamp(0, 1 << 31);

          // Force refresh collections to update recently added
          await collectionService.getCollections(forceRefresh: true);

          // Sync with Game Center for achievements
          _syncGameCenter();

          notifyListeners();
          emitRecipesChanged();
          return newRecipe;
        }
      } else {
        _setError(response.message ?? 'Failed to create recipe');
        return null;
      }
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
    return null;
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
  Future<bool> deleteUserRecipe(String id, BuildContext context) async {
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

          // Refresh collections to ensure the deleted recipe is removed from all collections
          await collectionService.refreshCollectionsAfterRecipeDeletion(id);

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
      debugPrint(
        '✅ Using valid session cache (${_sessionDiscoverCache.length} recipes)',
      );
      return; // Use existing cache
    }

    debugPrint('🔄 Fetching $_sessionCacheSize recipes for session cache...');
    clearError();
    _setLoading(true);

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
          
          // Shuffle immediately for true randomization (server returns all 500)
          _sessionDiscoverCache.shuffle();
          
          _sessionCacheTime = DateTime.now();
          debugPrint(
            '✅ Session cache populated and shuffled with ${_sessionDiscoverCache.length} recipes',
          );
        }
      } else {
        _setError(response.message ?? 'Failed to fetch discover recipes');
      }
    } catch (e) {
      debugPrint('❌ Error fetching session cache: $e');
      _setError('Failed to load recipes: $e');
    } finally {
      _setLoading(false);
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
    if (_sessionDiscoverCache.isEmpty) {
      return [];
    }

    // Filter from session cache
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

    // Apply tag filter
    if (tag != null && tag != 'All') {
      filtered =
          filtered
              .where(
                (r) => r.tags.any((t) => t.toLowerCase() == tag.toLowerCase()),
              )
              .toList();
    }

    // Apply text search filter (if query provided)
    if (query != null && query.isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      filtered =
          filtered
              .where(
                (r) =>
                    r.title.toLowerCase().contains(lowerQuery) ||
                    r.description.toLowerCase().contains(lowerQuery) ||
                    r.tags.any((t) => t.toLowerCase().contains(lowerQuery)),
              )
              .toList();
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

  // Randomize the session cache
  void randomizeSessionCache() {
    if (_sessionDiscoverCache.isNotEmpty) {
      _sessionDiscoverCache.shuffle();
      debugPrint(
        '🔀 Randomized session cache (${_sessionDiscoverCache.length} recipes)',
      );
      notifyListeners();
    }
  }

  // Clear session cache (force refresh)
  void clearSessionCache() {
    _sessionDiscoverCache.clear();
    _sessionCacheTime = null;
    debugPrint('🗑️ Session cache cleared');
  }

  // Set generated recipes from cache (internal helper)
  void setGeneratedRecipesFromCache(List<Recipe> recipes) {
    _generatedRecipes = recipes;
    notifyListeners();
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
          _setError('No recipes data received from server');
          return;
        }

        if (recipesList is! List) {
          _generatedRecipes = [];
          _setError('Invalid recipes data format received from server');
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
        _generatedRecipes = [];
      }
    } catch (e) {
      _setError(e.toString());
      _generatedRecipes = [];
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

  @override
  void dispose() {
    _recipesChangedController.close();
    super.dispose();
  }

  // Favorites removed: no favorite cache or flags
}
