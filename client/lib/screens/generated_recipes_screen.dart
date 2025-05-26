import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipease/components/floating_home_button.dart';
import '../providers/recipe_provider.dart';
import '../components/recipe_card.dart';
import '../components/custom_app_bar.dart';
import '../models/recipe.dart';
import '../components/error_display.dart';
import 'package:recipease/components/banner_ad.dart';
import '../services/recipe_service.dart';

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
    for (var recipe in recipeProvider.userRecipes) {
      _savedRecipes[recipe.id] = true;
    }
  }

  Future<void> _handleRecipeAction(Recipe recipe) async {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    final isCurrentlySaved = _savedRecipes[recipe.id] ?? false;

    if (isCurrentlySaved) {
      // Remove from collection
      setState(() {
        _savedRecipes[recipe.id] = false;
      });
      await recipeProvider.deleteUserRecipe(recipe.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recipe removed from your collection'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Go to My Recipes',
              onPressed: () {
                Navigator.pushNamed(context, '/myRecipes');
              },
            ),
          ),
        );
      }
    } else {
      setState(() {
        _savedRecipes[recipe.id] = true;
      });
      // Save to collection using standard recipe creation
      final response = await RecipeService.createUserRecipe(recipe);
      if (mounted) {
        if (response.success && response.data != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Recipe saved to your collection!'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Go to My Recipes',
                onPressed: () {
                  Navigator.pushNamed(context, '/myRecipes');
                },
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Failed to save recipe'),
              backgroundColor: Colors.red,
            ),
          );
          // Revert the saved state if save failed
          setState(() {
            _savedRecipes[recipe.id] = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Generated Recipes'),
      body: Stack(
        children: [
          Consumer<RecipeProvider>(
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
                    recipeProvider.generateRecipes();
                  },
                );
              }

              if (recipeProvider.generatedRecipes.isEmpty) {
                return const Center(child: Text('No generated recipes yet'));
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Generated Recipes:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...recipeProvider.generatedRecipes.map(
                      (recipe) => RecipeCard(
                        recipe: recipe,
                        showSaveButton: !(_savedRecipes[recipe.id] ?? false),
                        showRemoveButton: _savedRecipes[recipe.id] ?? false,
                        onSave: () => _handleRecipeAction(recipe),
                        onRemove: () => _handleRecipeAction(recipe),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          ),
          const FloatingHomeButton(),
          const BannerAdWidget(),
        ],
      ),
    );
  }
}
