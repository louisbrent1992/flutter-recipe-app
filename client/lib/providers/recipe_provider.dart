import 'package:flutter/material.dart';
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
    _isLoading = loading;
    notifyListeners();
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
  Future<void> loadUserRecipes({int page = 1, int limit = 10}) async {
    _setLoading(true);
    clearError();

    try {
      final response = await RecipeService.getUserRecipes(
        page: page,
        limit: limit,
      );

      if (response.success && response.data != null) {
        final data = response.data!;
        _userRecipes = (data['recipes'] as List).cast<Recipe>();
        _currentPage = data['pagination']['page'];
        _totalPages = data['pagination']['totalPages'];
        _hasNextPage = data['pagination']['hasNextPage'];
        _hasPrevPage = data['pagination']['hasPrevPage'];
        _totalRecipes = data['pagination']['total'];

        // Update favorite status for loaded recipes
        await _updateRecipeFavoriteStatus();

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

  // Helper method to update favorite status for loaded recipes
  Future<void> _updateRecipeFavoriteStatus() async {
    try {
      final favoritesResponse = await RecipeService.getFavoriteRecipes();

      if (favoritesResponse.success && favoritesResponse.data != null) {
        final favoriteIds = favoritesResponse.data ?? <String>[];

        // Update isFavorite field for each recipe
        for (int i = 0; i < _userRecipes.length; i++) {
          final recipe = _userRecipes[i];
          final recipeIdStr = recipe.id.toString();
          final isFavorite = favoriteIds.any(
            (favId) => favId.toString() == recipeIdStr,
          );

          if (recipe.isFavorite != isFavorite) {
            _userRecipes[i] = recipe.copyWith(isFavorite: isFavorite);
          }
        }
      }
    } catch (e) {
      // Silently continue if favorites check fails
      debugPrint('Error updating recipe favorite status: $e');
    }
  }

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
  }) async {
    _setLoading(true);
    clearError();

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
        final recipes =
            (data['recipes'] as List)
                .map((item) => Recipe.fromJson(item as Map<String, dynamic>))
                .toList();

        // Store both the generated recipes and the original set
        _generatedRecipes = recipes;

        _currentPage = data['pagination']['page'];
        _totalPages = data['pagination']['totalPages'];
        _hasNextPage = data['pagination']['hasNextPage'];
        _hasPrevPage = data['pagination']['hasPrevPage'];
        _totalRecipes = data['pagination']['total'];
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
}
