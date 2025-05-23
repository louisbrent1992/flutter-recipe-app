import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/recipe_provider.dart';
import '../components/recipe_card.dart';
import '../components/custom_app_bar.dart';
import '../models/recipe.dart';
import '../components/error_display.dart';

class ImportedRecipesScreen extends StatefulWidget {
  const ImportedRecipesScreen({super.key});

  @override
  State<ImportedRecipesScreen> createState() => _ImportedRecipesScreenState();
}

class _ImportedRecipesScreenState extends State<ImportedRecipesScreen> {
  final Map<String, bool> _savedRecipes = {};

  @override
  void initState() {
    super.initState();
    // Load any existing saved recipes
    _loadSavedRecipes();
  }

  void _loadSavedRecipes() {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    for (var recipe in recipeProvider.userRecipes) {
      _savedRecipes[recipe.id] = true;
    }
  }

  Future<void> _handleRecipeAction(Recipe recipe) async {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    final isSaved = _savedRecipes[recipe.id] ?? false;

    if (isSaved) {
      await recipeProvider.deleteUserRecipe(recipe.id);
    } else {
      await recipeProvider.saveGeneratedRecipe(recipe);
    }

    setState(() {
      _savedRecipes[recipe.id] = !isSaved;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Imported Recipes'),
      body: Consumer<RecipeProvider>(
        builder: (context, recipeProvider, _) {
          if (recipeProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (recipeProvider.error != null) {
            return ErrorDisplay(
              message: recipeProvider.error!.userFriendlyMessage,
              isNetworkError: recipeProvider.error!.isNetworkError,
              isAuthError: recipeProvider.error!.isAuthError,
              isFormatError: recipeProvider.error!.isFormatError,
              onRetry: () {
                recipeProvider.clearError();
                // Add retry logic here
              },
            );
          }

          if (recipeProvider.importedRecipe == null) {
            return const Center(child: Text('No imported recipes yet'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RecipeCard(
                  recipe: recipeProvider.importedRecipe!,
                  showSaveButton:
                      !(_savedRecipes[recipeProvider.importedRecipe!.id] ??
                          false),
                  showRemoveButton:
                      _savedRecipes[recipeProvider.importedRecipe!.id] ?? false,
                  onSave:
                      () => _handleRecipeAction(recipeProvider.importedRecipe!),
                  onRemove:
                      () => _handleRecipeAction(recipeProvider.importedRecipe!),
                  showEditButton: true,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
