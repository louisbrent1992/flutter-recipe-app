import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/recipe_provider.dart';
import '../components/recipe_card.dart';
import '../components/custom_app_bar.dart';
import '../models/recipe.dart';

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
          const SnackBar(
            content: Text('Recipe removed from your collection'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      setState(() {
        _savedRecipes[recipe.id] = true;
      });
      // Save to collection
      await recipeProvider.saveGeneratedRecipe(recipe);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipe saved to your collection!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Generated Recipes'),
      body: Consumer<RecipeProvider>(
        builder: (context, recipeProvider, _) {
          if (recipeProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (recipeProvider.error != null) {
            return Center(
              child: Text(
                recipeProvider.error!,
                style: const TextStyle(color: Colors.red),
              ),
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              ],
            ),
          );
        },
      ),
    );
  }
}
