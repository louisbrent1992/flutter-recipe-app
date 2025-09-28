import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/recipe.dart';
import '../services/google_image_service.dart';
import '../services/recipe_service.dart';

/// Progress callback that provides current progress, total count, and current recipe title
typedef ProgressCallback =
    void Function(int current, int total, String? recipeTitle);

/// Completion callback that provides number of images fixed
typedef CompletionCallback = void Function(int totalFixed, int totalChecked);

/// Service for bulk refreshing broken images in user's recipe collection
class BulkImageRefreshService {
  static const _imageUAHeaders = {
    'User-Agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Mobile/15E148 Safari/604.1',
    'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
  };

  /// Checks if an image URL is broken (returns 400, 403, or 404)
  static Future<bool> _isImageBroken(String imageUrl) async {
    try {
      final uri = Uri.parse(imageUrl);
      final response = await http
          .head(uri, headers: _imageUAHeaders)
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => http.Response('', 408),
          );

      // Consider 400, 403, 404 as broken images
      return response.statusCode == 400 ||
          response.statusCode == 403 ||
          response.statusCode == 404;
    } catch (e) {
      // Network errors also indicate broken images
      return true;
    }
  }

  /// Attempts to find a replacement image using Google Image Search
  static Future<String?> _findReplacementImage(String recipeTitle) async {
    try {
      return await GoogleImageService.fetchImageForQuery(
        '$recipeTitle recipe',
        start: 0, // Start fresh for bulk refresh
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error finding replacement image for "$recipeTitle": $e');
      }
      return null;
    }
  }

  /// Refreshes all broken images in the user's recipe collection
  ///
  /// [recipes] - List of user recipes to check and refresh
  /// [onProgress] - Callback called for each recipe processed
  /// [onCompletion] - Callback called when all recipes are processed
  ///
  /// Returns the number of images that were successfully fixed
  static Future<int> refreshAllBrokenImages(
    List<Recipe> recipes, {
    ProgressCallback? onProgress,
    CompletionCallback? onCompletion,
  }) async {
    int totalFixed = 0;
    int totalChecked = 0;

    for (int i = 0; i < recipes.length; i++) {
      final recipe = recipes[i];
      totalChecked++;

      // Report progress
      onProgress?.call(i + 1, recipes.length, recipe.title);

      // Skip recipes without image URLs
      if (recipe.imageUrl.isEmpty) {
        continue;
      }

      try {
        // Check if the current image is broken
        final isBroken = await _isImageBroken(recipe.imageUrl);

        if (isBroken) {
          if (kDebugMode) {
            print('Found broken image for recipe: ${recipe.title}');
          }

          // Try to find a replacement image
          final replacementUrl = await _findReplacementImage(recipe.title);

          if (replacementUrl != null && replacementUrl.isNotEmpty) {
            // Update the recipe with the new image URL
            final updatedRecipe = recipe.copyWith(imageUrl: replacementUrl);

            // Save the updated recipe
            final result = await RecipeService.updateUserRecipe(updatedRecipe);

            if (result.success) {
              totalFixed++;
              if (kDebugMode) {
                print('Successfully updated image for recipe: ${recipe.title}');
              }
            } else {
              if (kDebugMode) {
                print('Failed to save updated recipe: ${recipe.title}');
              }
            }
          } else {
            if (kDebugMode) {
              print(
                'Could not find replacement image for recipe: ${recipe.title}',
              );
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error processing recipe "${recipe.title}": $e');
        }
        // Continue with the next recipe even if one fails
        continue;
      }
    }

    // Report completion
    onCompletion?.call(totalFixed, totalChecked);

    return totalFixed;
  }

  /// Gets all user recipes across all pages for bulk refresh
  /// This is a helper method to fetch all user recipes regardless of pagination
  static Future<List<Recipe>> getAllUserRecipes() async {
    final allRecipes = <Recipe>[];
    int currentPage = 1;
    bool hasMore = true;

    while (hasMore) {
      try {
        final response = await RecipeService.getUserRecipes(
          page: currentPage,
          limit: 50, // Use larger page size for efficiency
        );

        if (response.success && response.data != null) {
          final data = response.data!;
          final recipesList = data['recipes'] as List<Recipe>?;
          final pagination = data['pagination'] as Map<String, dynamic>?;

          if (recipesList != null && recipesList.isNotEmpty) {
            allRecipes.addAll(recipesList);
          }

          // Check if there are more pages
          hasMore = pagination?['hasNextPage'] ?? false;
          currentPage++;
        } else {
          hasMore = false;
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error fetching user recipes page $currentPage: $e');
        }
        hasMore = false;
      }
    }

    if (kDebugMode) {
      print(
        'Retrieved ${allRecipes.length} total user recipes for bulk refresh',
      );
    }

    return allRecipes;
  }
}
