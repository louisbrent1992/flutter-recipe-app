import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';

class RecipeProvider extends ChangeNotifier {
  // AI generated recipes
  List<Recipe> _generatedRecipes = [];
  Recipe? _importedRecipe;
  bool _isLoading = false;
  String? _error;

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
  String? get error => _error;
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
    _error = errorMessage;
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
    _setError(null);

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
    _setError(null);

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

  // Save a generated recipe to the user's collection
  Future<Recipe?> saveGeneratedRecipe(Recipe recipe) async {
    _setLoading(true);
    _setError(null);

    try {
      // Check for duplicates
      if (isDuplicateRecipe(recipe)) {
        _setError('This recipe is already in your collection');
        return null;
      }

      final response = await RecipeService.createUserRecipe(recipe);

      if (response.success && response.data != null) {
        final savedRecipe = response.data;
        // Add to user recipes list
        _userRecipes.add(savedRecipe!);
        notifyListeners();
        return savedRecipe;
      } else {
        _setError(response.message ?? 'Failed to save recipe');
        return null;
      }
    } catch (e) {
      _setError(e.toString());
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
    _setError(null);

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
    _setError(null);

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
  Future<Recipe?> createUserRecipe(Recipe recipe) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await RecipeService.createUserRecipe(recipe);

      if (response.success && response.data != null) {
        final newRecipe = response.data;
        _userRecipes.add(newRecipe!);
        notifyListeners();
        return newRecipe;
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
  }

  // Update an existing user recipe
  Future<Recipe?> updateUserRecipe(Recipe recipe) async {
    _setLoading(true);
    _setError(null);

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
  Future<bool> deleteUserRecipe(String id) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await RecipeService.deleteUserRecipe(id);

      if (response.success) {
        // Remove from lists
        _userRecipes.removeWhere((recipe) => recipe.id == id);
        _favoriteRecipes.removeWhere((recipe) => recipe.id == id);

        notifyListeners();
        return true;
      } else {
        _setError(response.message ?? 'Failed to delete recipe');
        return false;
      }
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Toggle favorite status
  Future<bool> toggleFavorite(String id, bool isFavorite) async {
    _setError(null);

    try {
      final response = await RecipeService.toggleFavoriteStatus(id, isFavorite);

      if (response.success) {
        // Update in user recipes list
        final index = _userRecipes.indexWhere((r) => r.id == id);
        if (index != -1) {
          _userRecipes[index] = _userRecipes[index].copyWith(
            isFavorite: isFavorite,
          );
        }

        // Update favorites list
        if (isFavorite) {
          // If not already in favorites and marking as favorite, add it
          if (!_favoriteRecipes.any((r) => r.id == id) && index != -1) {
            _favoriteRecipes.add(_userRecipes[index]);
          }
        } else {
          // If removing from favorites, remove from list
          _favoriteRecipes.removeWhere((r) => r.id == id);
        }

        notifyListeners();

        // Refresh the favorites from the server to ensure collections are updated
        await loadFavoriteRecipes();

        return true;
      } else {
        _setError(response.message ?? 'Failed to update favorite status');
        return false;
      }
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // Load favorite recipes
  Future<void> loadFavoriteRecipes() async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await RecipeService.getFavoriteRecipes();

      if (response.success && response.data != null) {
        final favoriteIds = response.data ?? <String>[];

        // Filter the user recipes to find those with IDs in the favorites list
        _favoriteRecipes =
            _userRecipes
                .where((recipe) => favoriteIds.contains(recipe.id))
                .toList();

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
    _setError(null);

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
