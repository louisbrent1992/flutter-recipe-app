import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/recipe_provider.dart';
import '../theme/theme.dart';

/// A screen that fetches a random recipe and navigates to its detail page.
/// Used for daily inspiration notifications to show a specific recipe.
class RandomRecipeScreen extends StatefulWidget {
  const RandomRecipeScreen({super.key});

  @override
  State<RandomRecipeScreen> createState() => _RandomRecipeScreenState();
}

class _RandomRecipeScreenState extends State<RandomRecipeScreen> {
  @override
  void initState() {
    super.initState();
    // Defer the fetch until after the build phase completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAndNavigateToRandomRecipe();
    });
  }

  Future<void> _fetchAndNavigateToRandomRecipe() async {
    try {
      final recipeProvider = Provider.of<RecipeProvider>(
        context,
        listen: false,
      );

      // Fetch a random recipe (limit 1, random=true)
      await recipeProvider.searchExternalRecipes(
        query: '',
        tag: '',
        page: 1,
        limit: 1,
        random: true,
        forceRefresh: true,
      );

      if (!mounted) return;

      // Get the first recipe from the results
      final recipes = recipeProvider.generatedRecipes;
      if (recipes.isNotEmpty) {
        final randomRecipe = recipes.first;
        // Navigate to recipe detail screen
        Navigator.pushReplacementNamed(
          context,
          '/recipeDetail',
          arguments: randomRecipe,
        );
      } else {
        // If no recipe found, navigate to discover screen
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/discover',
            arguments: {'random': 'true'},
          );
        }
      }
    } catch (e) {
      // On error, navigate to discover screen as fallback
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/discover',
          arguments: {'random': 'true'},
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Finding your perfect recipe...',
              style: TextStyle(
                fontSize: AppTypography.responsiveFontSize(
                  context,
                  mobile: 16,
                  tablet: 18,
                  desktop: 20,
                ),
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

