import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../models/api_response.dart';
import '../services/recipe_service.dart';
import '../services/collection_service.dart';

class RecipeProvider extends ChangeNotifier {
  // AI generated recipes
  List<Recipe> _generatedRecipes = [];
  Recipe? _importedRecipe;
  bool _isLoading = false;
  ApiResponse<Recipe>? _error;

  // User recipes with pagination
  List<Recipe> _userRecipes = [];
  List<Recipe> _favoriteRecipes = [];
  int _currentPage = 1;
  int _totalPages = 1;
  bool _hasNextPage = false;
  bool _hasPrevPage = false;
  int _totalRecipes = 0;

  // Lightweight in-memory caches to reduce network calls and jank
  // Cache user recipes by page
  final Map<int, List<Recipe>> _userRecipesCache = {};
  final Map<int, Map<String, dynamic>> _userPaginationCache = {};

  // Cache generated/external search results by a composite key and page
  // key format: query=<q>|difficulty=<d>|tag=<t>|limit=<l>
  final Map<String, Map<int, List<Recipe>>> _generatedRecipesCache = {};
  final Map<String, Map<int, Map<String, dynamic>>> _generatedPaginationCache =
      {};

  // Cache favorite ids to avoid fetching repeatedly
  Set<String> _favoriteIdsCache = <String>{};
  DateTime? _favoritesLastFetchedAt;
  static const Duration _favoritesTtl = Duration(seconds: 60);

  // Getters
  List<Recipe> get generatedRecipes => _generatedRecipes;
  Recipe? get importedRecipe => _importedRecipe;
  bool get isLoading => _isLoading;
  ApiResponse<Recipe>? get error => _error;
  List<Recipe> get userRecipes => _userRecipes;
  List<Recipe> get favoriteRecipes => _favoriteRecipes;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  bool get hasNextPage => _hasNextPage;
  bool get hasPrevPage => _hasPrevPage;
  int get totalRecipes => _totalRecipes;

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
    _setLoading(true);
    clearError();

    try {
      final response = await RecipeService.generateRecipes(
        ingredients: ingredients,
        dietaryRestrictions: dietaryRestrictions,
        cuisineType: cuisineType,
        random: random,
      );

      if (response.success && response.data != null) {
        _generatedRecipes = response.data ?? [];
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
  Future<Recipe?> importRecipeFromUrl(String url, BuildContext context) async {
    _setLoading(true);
    clearError();

    try {
      final response = await RecipeService.importRecipeFromUrl(url);

      if (response.success && response.data != null) {
        final recipe = response.data!;

        // Check for duplicates
        if (isDuplicateRecipe(recipe)) {
          _setError('This recipe is already in your collection');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'This recipe is already in your collection',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return null;
        }

        _importedRecipe = recipe;
        notifyListeners();
        return _importedRecipe;
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

    // Serve from cache if available and not forced
    if (!forceRefresh && _userRecipesCache.containsKey(page)) {
      _userRecipes = _userRecipesCache[page] ?? [];
      final pagination = _userPaginationCache[page];
      if (pagination != null) {
        _currentPage = pagination['page'] ?? page;
        _totalPages = pagination['totalPages'] ?? _totalPages;
        _hasNextPage = pagination['hasNextPage'] ?? _hasNextPage;
        _hasPrevPage = pagination['hasPrevPage'] ?? _hasPrevPage;
        _totalRecipes = pagination['total'] ?? _userRecipes.length;
      }
      notifyListeners();
      // Ensure favorite flags are kept in sync using cached ids (non-blocking)
      // Do not set loading to true to avoid jank when serving from cache
      // Just refresh favorites in background if TTL expired
      // fire and forget refresh of favorites
      _ensureFavoriteIdsFresh().then((_) => _applyFavoriteFlagsFromCache());
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

        _userRecipes = recipesList.cast<Recipe>();

        // Cache the page data
        _userRecipesCache[page] = List<Recipe>.unmodifiable(_userRecipes);

        // Safely handle pagination data
        final pagination = data['pagination'];
        if (pagination != null && pagination is Map<String, dynamic>) {
          _currentPage = pagination['page'] ?? 1;
          _totalPages = pagination['totalPages'] ?? 1;
          _hasNextPage = pagination['hasNextPage'] ?? false;
          _hasPrevPage = pagination['hasPrevPage'] ?? false;
          _totalRecipes = pagination['total'] ?? 0;

          // Cache pagination per page
          _userPaginationCache[page] = Map<String, dynamic>.from(pagination);
        } else {
          // Fallback values if pagination data is missing
          _currentPage = 1;
          _totalPages = 1;
          _hasNextPage = false;
          _hasPrevPage = false;
          _totalRecipes = _userRecipes.length;
          _userPaginationCache[page] = {
            'page': _currentPage,
            'totalPages': _totalPages,
            'hasNextPage': _hasNextPage,
            'hasPrevPage': _hasPrevPage,
            'total': _totalRecipes,
          };
        }

        // Update favorite status for loaded recipes
        await _ensureFavoriteIdsFresh();
        _applyFavoriteFlagsFromCache();

        notifyListeners();
      } else {
        _setError(response.message ?? 'Failed to load recipes');
        _userRecipes = [];
      }
    } catch (e) {
      _setError(e.toString());
      _userRecipes = [];
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
      return null;
    }

    _setLoading(true);
    clearError();

    try {
      final response = await RecipeService.createUserRecipe(recipe);

      if (context.mounted) {
        final collectionService = context.read<CollectionService>();

        if (response.success && response.data != null) {
          final newRecipe = response.data;
          _userRecipes.add(newRecipe!);

          // Force refresh collections to update recently added
          await collectionService.getCollections(forceRefresh: true);

          notifyListeners();
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

        // Also update in favorites list if present
        final favIndex = _favoriteRecipes.indexWhere((r) => r.id == recipe.id);
        if (favIndex != -1) {
          _favoriteRecipes[favIndex] = updatedRecipe!;
        }

        notifyListeners();
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
          _favoriteRecipes.removeWhere((recipe) => recipe.id == id);
          _generatedRecipes.removeWhere((recipe) => recipe.id == id);

          // Clear imported recipe if it matches
          if (_importedRecipe?.id == id) {
            _importedRecipe = null;
          }

          // Refresh collections to ensure the deleted recipe is removed from all collections
          await collectionService.refreshCollectionsAfterRecipeDeletion(id);

          notifyListeners();
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

  // Toggle favorite status
  Future<bool> toggleFavorite(
    String id,
    bool isFavorite,
    BuildContext context,
  ) async {
    clearError();

    try {
      final response = await RecipeService.toggleFavoriteStatus(id, isFavorite);

      if (context.mounted) {
        final collectionService = context.read<CollectionService>();

        if (response.success) {
          // Update in user recipes list - handle string/number ID comparison
          final index = _userRecipes.indexWhere(
            (r) => r.id.toString() == id.toString(),
          );
          if (index != -1) {
            _userRecipes[index] = _userRecipes[index].copyWith(
              isFavorite: isFavorite,
            );
          }

          // Update favorites list
          if (isFavorite) {
            // If not already in favorites and marking as favorite, add it
            if (!_favoriteRecipes.any(
                  (r) => r.id.toString() == id.toString(),
                ) &&
                index != -1) {
              final recipeToAdd = _userRecipes[index];
              _favoriteRecipes.add(recipeToAdd);
              // Add to favorites collection using the correct recipe
              await collectionService.addRecipeToCollection(
                'Favorites',
                recipeToAdd,
              );
            }
          } else {
            // If removing from favorites, remove from list
            _favoriteRecipes.removeWhere(
              (r) => r.id.toString() == id.toString(),
            );
            // Remove from favorites collection
            await collectionService.removeRecipeFromCollection('Favorites', id);
          }

          // Force refresh the favorites collection to ensure it's in sync
          await collectionService.getCollections(forceRefresh: true);

          notifyListeners();
          return true;
        } else {
          _setError(response.message ?? 'Failed to toggle favorite status');
          return false;
        }
      }
    } catch (e) {
      _setError(e.toString());
      return false;
    }
    return false;
  }

  // Load favorite recipes
  Future<void> loadFavoriteRecipes() async {
    _setLoading(true);
    clearError();

    try {
      final response = await RecipeService.getFavoriteRecipes();

      if (response.success && response.data != null) {
        final favoriteIds = response.data ?? <String>[];

        // Filter the user recipes to find those with IDs in the favorites list
        // Convert both to strings for comparison to handle mixed types
        _favoriteRecipes =
            _userRecipes.where((recipe) {
              final recipeIdStr = recipe.id.toString();
              return favoriteIds.any(
                (favId) => favId.toString() == recipeIdStr,
              );
            }).toList();

        notifyListeners();
      } else {
        _setError(response.message ?? 'Failed to load favorite recipes');
        _favoriteRecipes = [];
      }
    } catch (e) {
      _setError(e.toString());
      _favoriteRecipes = [];
    } finally {
      _setLoading(false);
    }
  }

  // Deprecated: kept for reference during refactor
  // Favorite flags are now applied from cached ids via _applyFavoriteFlagsFromCache()

  // Refresh all data
  Future<void> refreshAll() async {
    await loadUserRecipes();
    await loadFavoriteRecipes();
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

  //----------------------------------------
  // API SEARCH METHODS
  //----------------------------------------

  // Search for recipes from external API
  Future<void> searchExternalRecipes({
    String? query,
    String? difficulty,
    String? tag,
    int page = 1,
    int limit = 10,
    bool forceRefresh = false,
  }) async {
    clearError();

    // Build a stable cache key for query+filters+limit
    final String cacheKey = _buildSearchKey(
      query: query,
      difficulty: difficulty,
      tag: tag,
      limit: limit,
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
          _currentPage = pagination['page'] ?? 1;
          _totalPages = pagination['totalPages'] ?? 1;
          _hasNextPage = pagination['hasNextPage'] ?? false;
          _hasPrevPage = pagination['hasPrevPage'] ?? false;
          _totalRecipes = pagination['total'] ?? 0;
          _generatedPaginationCache.putIfAbsent(
            cacheKey,
            () => <int, Map<String, dynamic>>{},
          );
          _generatedPaginationCache[cacheKey]![page] =
              Map<String, dynamic>.from(pagination);
        } else {
          // Fallback values if pagination data is missing
          _currentPage = 1;
          _totalPages = 1;
          _hasNextPage = false;
          _hasPrevPage = false;
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
  }) {
    final q = (query ?? '').trim().toLowerCase();
    final d = (difficulty ?? 'All').trim();
    final t = (tag ?? 'All').trim();
    final l = (limit ?? 10).toString();
    return 'query=$q|difficulty=$d|tag=$t|limit=$l';
  }

  Future<void> _ensureFavoriteIdsFresh() async {
    final now = DateTime.now();
    final isStale =
        _favoritesLastFetchedAt == null ||
        now.difference(_favoritesLastFetchedAt!) > _favoritesTtl;
    if (!isStale) return;

    try {
      final response = await RecipeService.getFavoriteRecipes();
      if (response.success && response.data != null) {
        _favoriteIdsCache = response.data!.map((e) => e.toString()).toSet();
        _favoritesLastFetchedAt = now;
      }
    } catch (_) {
      // ignore errors; we'll try again later
    }
  }

  void _applyFavoriteFlagsFromCache() {
    if (_favoriteIdsCache.isEmpty) return;
    for (int i = 0; i < _userRecipes.length; i++) {
      final recipe = _userRecipes[i];
      final idStr = recipe.id.toString();
      final isFav = _favoriteIdsCache.contains(idStr);
      if (recipe.isFavorite != isFav) {
        _userRecipes[i] = recipe.copyWith(isFavorite: isFav);
      }
    }
  }
}
