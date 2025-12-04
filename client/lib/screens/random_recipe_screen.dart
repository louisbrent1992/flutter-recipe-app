import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../providers/recipe_provider.dart';
import '../services/local_storage_service.dart';
import '../services/recipe_service.dart';
import '../theme/theme.dart';

/// A screen that fetches a random recipe and navigates to its detail page.
/// Used for daily inspiration notifications to show a specific recipe.
/// 
/// Optimized for fast navigation:
/// 1. Check in-memory cache (instant)
/// 2. Check local Hive storage (fast I/O)
/// 3. Fetch single random recipe from API (fast, only 1 recipe)
/// 4. Trigger full discover cache refresh in background (non-blocking)
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

      // STEP 1: Try in-memory cache first (instant - no I/O)
      final cachedRecipe = recipeProvider.getDailyRandomRecipeFromCache();
      if (cachedRecipe != null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          '/recipeDetail',
          arguments: cachedRecipe,
        );
        return;
      }

      // STEP 2: Try local Hive storage directly (fast I/O, ~50-100ms)
      // This bypasses the full fetchSessionDiscoverCache which waits for network
      final localStorage = LocalStorageService();
      final localCache = await localStorage.loadDiscoverCache();
      
      if (localCache.isNotEmpty) {
        // Get daily random recipe from local cache using same algorithm
        final dailyRecipe = _getDailyRandomFromList(localCache);
        if (dailyRecipe != null && mounted) {
          // Populate provider cache in background (non-blocking)
          recipeProvider.setDiscoverCacheFromList(localCache);
          
          Navigator.pushReplacementNamed(
            context,
            '/recipeDetail',
            arguments: dailyRecipe,
          );
          return;
        }
      }

      // STEP 3: Fetch single random recipe from API (fast - only 1 recipe)
      // This is much faster than fetching 500 recipes
      if (!mounted) return;
      
      final response = await RecipeService.searchExternalRecipes(
        limit: 1,
        random: true,
      );

      if (!mounted) return;

      if (response.success && response.data != null) {
        final data = response.data!;
        final recipesList = data['recipes'];
        
        if (recipesList != null && recipesList is List && recipesList.isNotEmpty) {
          final recipe = Recipe.fromJson(recipesList.first as Map<String, dynamic>);
          
          // Trigger full discover cache refresh in background (non-blocking)
          // This prepares the cache for next time without blocking navigation
          recipeProvider.fetchSessionDiscoverCache(forceRefresh: false);
          
          Navigator.pushReplacementNamed(
            context,
            '/recipeDetail',
            arguments: recipe,
          );
          return;
        }
      }

      // STEP 4: Fallback - navigate to discover screen
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/discover',
          arguments: {'random': 'true'},
        );
      }
    } catch (e) {
      // On error, navigate to discover screen as fallback
      debugPrint('Error in random recipe navigation: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/discover',
          arguments: {'random': 'true'},
        );
      }
    }
  }

  /// Get daily random recipe from a list using deterministic selection
  /// Same algorithm as RecipeProvider.getDailyRandomRecipeFromCache()
  Recipe? _getDailyRandomFromList(List<Recipe> recipes) {
    if (recipes.isEmpty) return null;
    
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final dayOfYear = now.difference(start).inDays + 1;
    final dailyIndex = (now.year * 365 + dayOfYear) % recipes.length;
    
    return recipes[dailyIndex];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
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
