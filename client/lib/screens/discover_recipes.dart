import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipease/components/custom_app_bar.dart';
import '../providers/recipe_provider.dart';
import '../components/recipe_card.dart';
import '../components/floating_home_button.dart';
import '../components/recipe_filter_bar.dart';
import '../mixins/recipe_filter_mixin.dart';
import '../models/recipe.dart';
import '../components/error_display.dart';

class DiscoverRecipesScreen extends StatefulWidget {
  const DiscoverRecipesScreen({super.key});

  @override
  State<DiscoverRecipesScreen> createState() => _DiscoverRecipesScreenState();
}

class _DiscoverRecipesScreenState extends State<DiscoverRecipesScreen>
    with RecipeFilterMixin {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDifficulty = 'All';
  String _selectedTag = 'All';
  final Map<String, bool> _savedRecipes = {};
  final List<String> _difficulties = ['All', 'Easy', 'Medium', 'Hard'];
  final List<String> _availableTags = [
    'All',
    'Breakfast',
    'Lunch',
    'Dinner',
    'Dessert',
    'Vegetarian',
    'Vegan',
    'Gluten-Free',
    'Quick & Easy',
    'Healthy',
    'Comfort Food',
    'Italian',
    'Mexican',
    'Asian',
    'Mediterranean',
  ];

  @override
  void initState() {
    super.initState();
    // Load recipes after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecipes();
      _loadSavedRecipes();
    });
  }

  void _loadSavedRecipes() {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    for (var recipe in recipeProvider.userRecipes) {
      _savedRecipes[recipe.id] = true;
    }
  }

  // Load recipes from external API
  Future<void> _loadRecipes() async {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    await recipeProvider.searchExternalRecipes(
      query: _searchQuery.isEmpty ? null : _searchQuery,
      difficulty: _selectedDifficulty == 'All' ? null : _selectedDifficulty,
      tag: _selectedTag == 'All' ? null : _selectedTag,
    );
  }

  // Reset all filters and restore original recipes
  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedDifficulty = 'All';
      _selectedTag = 'All';
    });
    _loadRecipes(); // Reload recipes with reset filters
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
      // Check for duplicates before saving
      if (recipeProvider.isDuplicateRecipe(recipe)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This recipe is already in your collection'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Save to collection using RecipeProvider
      final savedRecipe = await recipeProvider.createUserRecipe(recipe);
      if (savedRecipe != null) {
        setState(() {
          _savedRecipes[recipe.id] = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recipe saved to your collection!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save recipe'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Discover Recipes'),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: RecipeFilterBar(
                  searchController: _searchController,
                  searchQuery: _searchQuery,
                  selectedDifficulty: _selectedDifficulty,
                  selectedTag: _selectedTag,
                  difficulties: _difficulties,
                  availableTags: _availableTags,
                  onSearchChanged: (value) {
                    setState(() => _searchQuery = value);
                    // Add debounce for search to avoid too many API calls
                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (_searchQuery == value) {
                        _loadRecipes();
                      }
                    });
                  },
                  onDifficultySelected: (difficulty) {
                    setState(() => _selectedDifficulty = difficulty);
                    _loadRecipes();
                  },
                  onTagSelected: (tag) {
                    setState(() => _selectedTag = tag);
                    _loadRecipes();
                  },
                  showResetButton:
                      _selectedDifficulty != 'All' ||
                      _selectedTag != 'All' ||
                      _searchQuery.isNotEmpty,
                  onResetFilters: _resetFilters,
                ),
              ),
              Expanded(
                child: Consumer<RecipeProvider>(
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
                          _loadRecipes();
                        },
                      );
                    }

                    final recipes = recipeProvider.generatedRecipes;

                    if (recipes.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No recipes found',
                              style: Theme.of(context).textTheme.headlineLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try adjusting your search or filters',
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemCount: recipes.length,
                      itemBuilder: (context, index) {
                        final recipe = recipes[index];
                        return RecipeCard(
                          recipe: recipe,
                          showSaveButton: !(_savedRecipes[recipe.id] ?? false),
                          showRemoveButton: _savedRecipes[recipe.id] ?? false,
                          onSave: () => _handleRecipeAction(recipe),
                          onRemove: () => _handleRecipeAction(recipe),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          const FloatingHomeButton(),
        ],
      ),
    );
  }
}
