import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/recipe.dart';
import '../models/api_response.dart';
import 'api_client.dart';

class RecipeService {
  static final ApiClient _api = ApiClient();

  // Base URL for API
  static String get baseUrl {
    // Android emulator uses 10.0.2.2 to access host's localhost
    // iOS simulator can use localhost directly
    if (kIsWeb) return 'http://localhost:3001/api';
    return Platform.isAndroid
        ? 'http://10.0.2.2:3001/api'
        : 'http://localhost:3001/api';
  }

  //----------------------------------------
  // AI-GENERATED RECIPES (No auth required)
  //----------------------------------------

  /// Generate recipes using AI
  static Future<ApiResponse<List<Recipe>>> generateRecipes({
    List<String>? ingredients,
    List<String>? dietaryRestrictions,
    String? cuisineType,
    bool random = false,
  }) async {
    final Map<String, dynamic> payload = {
      if (ingredients != null && ingredients.isNotEmpty)
        'ingredients': ingredients,
      if (dietaryRestrictions != null && dietaryRestrictions.isNotEmpty)
        'dietaryRestrictions': dietaryRestrictions,
      if (cuisineType != null && cuisineType.isNotEmpty)
        'cuisineType': cuisineType,
      'random': random,
    };

    final response = await _api.publicPost<List<dynamic>>(
      'ai/recipes/generate',
      body: payload,
    );

    if (response.success && response.data != null) {
      final recipes =
          (response.data as List)
              .map((item) => Recipe.fromJson(item as Map<String, dynamic>))
              .toList();
      return ApiResponse.success(recipes);
    }

    return ApiResponse.error(
      response.message ?? 'Failed to generate recipes',
      statusCode: response.statusCode,
    );
  }

  /// Import recipe from social media URL
  static Future<ApiResponse<Recipe>> importRecipeFromUrl(String url) async {
    final response = await _api.publicPost<Map<String, dynamic>>(
      'ai/recipes/import',
      body: {'url': url},
    );

    if (response.success && response.data != null) {
      return ApiResponse.success(
        Recipe.fromJson(response.data!),
        message: 'Recipe imported successfully',
      );
    }

    return ApiResponse.error(
      response.message ?? 'Failed to import recipe',
      statusCode: response.statusCode,
    );
  }

  //----------------------------------------
  // USER RECIPES (Auth required)
  //----------------------------------------

  /// Get all user recipes
  static Future<ApiResponse<List<Recipe>>> getUserRecipes() async {
    final response = await _api.authenticatedGet<List<dynamic>>('user/recipes');

    if (response.success && response.data != null) {
      final recipes =
          (response.data as List)
              .map((item) => Recipe.fromJson(item as Map<String, dynamic>))
              .toList();
      return ApiResponse.success(recipes);
    }

    return ApiResponse.error(
      response.message ?? 'Failed to get user recipes',
      statusCode: response.statusCode,
    );
  }

  /// Get a specific user recipe
  static Future<ApiResponse<Recipe>> getUserRecipe(String id) async {
    final response = await _api.authenticatedGet<Map<String, dynamic>>(
      'user/recipes/$id',
    );

    if (response.success && response.data != null) {
      return ApiResponse.success(Recipe.fromJson(response.data!));
    }

    return ApiResponse.error(
      response.message ?? 'Failed to get recipe',
      statusCode: response.statusCode,
    );
  }

  /// Create a new user recipe
  static Future<ApiResponse<Recipe>> createUserRecipe(Recipe recipe) async {
    final response = await _api.authenticatedPost<Map<String, dynamic>>(
      'user/recipes',
      body: recipe.toJson(),
    );

    if (response.success && response.data != null) {
      return ApiResponse.success(
        Recipe.fromJson(response.data!),
        message: 'Recipe created successfully',
      );
    }

    return ApiResponse.error(
      response.message ?? 'Failed to create recipe',
      statusCode: response.statusCode,
    );
  }

  /// Update an existing user recipe
  static Future<ApiResponse<Recipe>> updateUserRecipe(Recipe recipe) async {
    final response = await _api.authenticatedPut<Map<String, dynamic>>(
      'user/recipes/${recipe.id}',
      body: recipe.toJson(),
    );

    if (response.success && response.data != null) {
      return ApiResponse.success(
        Recipe.fromJson(response.data!),
        message: 'Recipe updated successfully',
      );
    }

    return ApiResponse.error(
      response.message ?? 'Failed to update recipe',
      statusCode: response.statusCode,
    );
  }

  /// Delete a user recipe
  static Future<ApiResponse<bool>> deleteUserRecipe(String id) async {
    final response = await _api.authenticatedDelete('user/recipes/$id');

    if (response.success) {
      return ApiResponse.success(true, message: 'Recipe deleted successfully');
    }

    return ApiResponse.error(
      response.message ?? 'Failed to delete recipe',
      statusCode: response.statusCode,
    );
  }

  /// Toggle favorite status of a recipe
  static Future<ApiResponse<bool>> toggleFavoriteStatus(
    String id,
    bool isFavorite,
  ) async {
    final response = await _api.authenticatedPut(
      'user/recipes/$id/favorite',
      body: {'isFavorite': isFavorite},
    );

    if (response.success) {
      return ApiResponse.success(
        true,
        message:
            isFavorite
                ? 'Recipe added to favorites'
                : 'Recipe removed from favorites',
      );
    }

    return ApiResponse.error(
      response.message ?? 'Failed to update favorite status',
      statusCode: response.statusCode,
    );
  }

  /// Get all favorite recipes
  static Future<ApiResponse<List<Recipe>>> getFavoriteRecipes() async {
    final response = await _api.authenticatedGet<List<dynamic>>(
      'user/recipes/favorites',
    );

    print('favorites: ${response.data}');

    if (response.success && response.data != null) {
      final recipes =
          (response.data as List)
              .map((item) => Recipe.fromJson(item as Map<String, dynamic>))
              .toList();
      return ApiResponse.success(recipes);
    }

    return ApiResponse.error(
      response.message ?? 'Failed to get favorite recipes',
      statusCode: response.statusCode,
    );
  }

  /// Save AI-generated recipe to user collection
  static Future<ApiResponse<Recipe>> saveAiRecipeToUserCollection(
    Recipe recipe,
  ) async {
    final response = await _api.authenticatedPost<Map<String, dynamic>>(
      'user/recipes/save-from-ai',
      body: {'recipe': recipe.toJson()},
    );

    if (response.success && response.data != null) {
      return ApiResponse.success(
        Recipe.fromJson(response.data!),
        message: 'Recipe saved to your collection',
      );
    }

    return ApiResponse.error(
      response.message ?? 'Failed to save AI recipe',
      statusCode: response.statusCode,
    );
  }
}
