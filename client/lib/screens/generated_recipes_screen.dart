import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/recipe_provider.dart';
import '../components/recipe_card.dart';
import '../components/custom_app_bar.dart';
import '../models/recipe.dart';
import '../components/error_display.dart';
import '../theme/theme.dart';
import '../utils/snackbar_helper.dart';

class GeneratedRecipesScreen extends StatefulWidget {
  const GeneratedRecipesScreen({super.key});

  @override
  GeneratedRecipesScreenState createState() => GeneratedRecipesScreenState();
}

class GeneratedRecipesScreenState extends State<GeneratedRecipesScreen> {
  final Map<String, bool> _savedRecipes = {};

  @override
  void initState() {
    super.initState();
    // Load any existing saved recipes
    _loadSavedRecipes();
  }

  void _loadSavedRecipes() {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    final userRecipes = recipeProvider.userRecipes;

    // Mark saved recipes by ID
    for (var recipe in userRecipes) {
      _savedRecipes[recipe.id] = true;
    }

    // Also check AI generated recipes and mark them if they match saved ones
    for (var aiRecipe in recipeProvider.aiGeneratedRecipes) {
      if (_isRecipeSaved(aiRecipe, userRecipes)) {
        _savedRecipes[aiRecipe.id] = true;
      }
    }
  }

  /// Check if a recipe is already saved using multiple matching strategies
  bool _isRecipeSaved(Recipe recipe, List<Recipe> userRecipes) {
    // Check by ID
    if (userRecipes.any((r) => r.id == recipe.id)) {
      return true;
    }

    // Check by sourceUrl
    if (recipe.sourceUrl != null && recipe.sourceUrl!.isNotEmpty) {
      if (userRecipes.any((r) => r.sourceUrl == recipe.sourceUrl)) {
        return true;
      }
    }

    // Check by title + description
    final recipeKey =
        '${recipe.title.toLowerCase()}|${recipe.description.toLowerCase()}';
    return userRecipes.any(
      (r) =>
          '${r.title.toLowerCase()}|${r.description.toLowerCase()}' ==
          recipeKey,
    );
  }

  Future<void> _handleRecipeAction(Recipe recipe) async {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    final userRecipes = recipeProvider.userRecipes;

    // Check if recipe is already saved using consistent logic
    bool isAlreadySaved = userRecipes.any((r) => r.id == recipe.id);

    // Check by sourceUrl (most reliable for external recipes)
    if (!isAlreadySaved &&
        recipe.sourceUrl != null &&
        recipe.sourceUrl!.isNotEmpty) {
      isAlreadySaved = userRecipes.any((r) => r.sourceUrl == recipe.sourceUrl);
    }

    // Fallback to title + description
    if (!isAlreadySaved) {
      final recipeKey =
          '${recipe.title.toLowerCase()}|${recipe.description.toLowerCase()}';
      isAlreadySaved = userRecipes.any(
        (r) =>
            '${r.title.toLowerCase()}|${r.description.toLowerCase()}' ==
            recipeKey,
      );
    }

    if (isAlreadySaved) {
      // Find the saved recipe to delete
      Recipe? userRecipe = userRecipes.firstWhere(
        (r) => r.id == recipe.id,
        orElse: () => Recipe(),
      );

      if (userRecipe.id.isEmpty &&
          recipe.sourceUrl != null &&
          recipe.sourceUrl!.isNotEmpty) {
        userRecipe = userRecipes.firstWhere(
          (r) => r.sourceUrl == recipe.sourceUrl,
          orElse: () => Recipe(),
        );
      }

      if (userRecipe.id.isEmpty) {
        userRecipe = userRecipes.firstWhere(
          (r) =>
              r.title.toLowerCase() == recipe.title.toLowerCase() &&
              r.description.toLowerCase() == recipe.description.toLowerCase(),
          orElse: () => Recipe(),
        );
      }

      if (userRecipe.id.isNotEmpty) {
        // Remove from collection
        setState(() {
          _savedRecipes[recipe.id] = false;
        });
        final success = await recipeProvider.deleteUserRecipe(
          userRecipe.id,
          context,
          refreshCollections: false,
        );
        if (success && mounted) {
          SnackBarHelper.showWarning(
            context,
            'Recipe removed from your collection!',
          );
        }
      }
    } else {
      // Save to collection using RecipeProvider (handles duplicates, local storage, etc.)
      final savedRecipe = await recipeProvider.createUserRecipe(
        recipe,
        context,
        refreshCollections: false,
      );

      if (savedRecipe != null) {
        setState(() {
          _savedRecipes[recipe.id] = true;
          // Also track the new ID if it changed
          if (savedRecipe.id != recipe.id) {
            _savedRecipes[savedRecipe.id] = true;
          }
        });

        if (mounted) {
          SnackBarHelper.showSuccess(
            context,
            'Recipe saved to your collection!',
            action: SnackBarAction(
              label: 'Go to My Recipes',
              textColor: Colors.white,
              onPressed: () {
                if (mounted) {
                  Navigator.pushNamed(context, '/myRecipes');
                }
              },
            ),
          );
        }
      } else {
        // Provider handles showing error messages including duplicate detection
        // with "View Recipe" action, so we just need to handle UI state
        if (mounted) {
          if (recipeProvider.error != null) {
            final errorMessage =
                recipeProvider.error!.message ?? 'Failed to save recipe';
            final isDuplicate = errorMessage.contains('already exists');

            if (!isDuplicate) {
              // Only show error if not a duplicate (duplicate shows its own snackbar)
              SnackBarHelper.showError(context, errorMessage);
            }
            recipeProvider.clearError();
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Generated',
        fullTitle: 'Generated Recipes',
      ),
      body: Stack(
        children: [
          Consumer<RecipeProvider>(
            builder: (context, recipeProvider, _) {
              // Only show loading spinner if we have no recipes to display
              // This prevents flash during background save/delete operations
              if (recipeProvider.isLoading && recipeProvider.aiGeneratedRecipes.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (recipeProvider.error != null && recipeProvider.aiGeneratedRecipes.isEmpty) {
                return ErrorDisplay(
                  message: recipeProvider.error!.userFriendlyMessage,
                  isNetworkError: recipeProvider.error!.isNetworkError,
                  isAuthError: recipeProvider.error!.isAuthError,
                  isFormatError: recipeProvider.error!.isFormatError,
                  onRetry: () {
                    recipeProvider.clearError();
                    recipeProvider.generateRecipes();
                  },
                );
              }

              if (recipeProvider.aiGeneratedRecipes.isEmpty) {
                return const Center(child: Text('No generated recipes yet'));
              }

              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: AppSpacing.responsive(context),
                  right: AppSpacing.responsive(context),
                  top: AppSpacing.responsive(context),
                  bottom: AppSpacing.responsive(context) + 30, // Extra space for floating bar
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: AppSpacing.sm),
                    ...recipeProvider.aiGeneratedRecipes.map(
                      (recipe) => RecipeCard(
                        recipe: recipe,
                        showSaveButton: !(_savedRecipes[recipe.id] ?? false),
                        showRemoveButton: _savedRecipes[recipe.id] ?? false,
                        showRefreshButton: false, // Hide refresh button for generated recipes
                        onSave: () => _handleRecipeAction(recipe),
                        onRemove: () => _handleRecipeAction(recipe),
                      ),
                    ),
                    SizedBox(height: AppSpacing.responsive(context)),
                  ],
                ),
              );
            },
          ),
        ],
        ),
      );
  }
}
