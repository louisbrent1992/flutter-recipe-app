import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipease/components/custom_app_bar.dart';
import '../providers/recipe_provider.dart';
import '../components/recipe_card.dart';
import '../components/compact_filter_bar.dart';
import '../mixins/recipe_filter_mixin.dart';
import '../models/recipe.dart';
import '../components/error_display.dart';
import '../theme/theme.dart';
import '../components/floating_bottom_bar.dart';

class DiscoverRecipesScreen extends StatefulWidget {
  const DiscoverRecipesScreen({super.key});

  @override
  State<DiscoverRecipesScreen> createState() => _DiscoverRecipesScreenState();
}

class _DiscoverRecipesScreenState extends State<DiscoverRecipesScreen>
    with RecipeFilterMixin {
  final ScrollController _scrollController = ScrollController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDifficulty = 'All';
  String _selectedTag = 'All';
  int _currentPage = 1;
  static const int _itemsPerPage = 12;
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
    });
  }

  // Load recipes from external API
  Future<void> _loadRecipes() async {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    await recipeProvider.searchExternalRecipes(
      query: _searchQuery.isEmpty ? null : _searchQuery,
      difficulty: _selectedDifficulty == 'All' ? null : _selectedDifficulty,
      tag: _selectedTag == 'All' ? null : _selectedTag,
      page: _currentPage,
      limit: _itemsPerPage,
    );
  }

  // Reset all filters and go to page 1
  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedDifficulty = 'All';
      _selectedTag = 'All';
      _currentPage = 1;
    });
    _loadRecipes(); // Reload recipes with reset filters
  }

  // Handle page navigation
  void _goToPage(int page) {
    setState(() {
      _currentPage = page;
    });
    _loadRecipes();
    // Scroll to top when changing pages
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goToPreviousPage() {
    if (_currentPage > 1) {
      _goToPage(_currentPage - 1);
    }
  }

  void _goToNextPage() {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    if (recipeProvider.hasNextPage) {
      _goToPage(_currentPage + 1);
    }
  }

  Future<void> _handleRecipeAction(Recipe recipe) async {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);

    // Check if recipe is already saved
    final userRecipeIds = recipeProvider.userRecipes.map((r) => r.id).toSet();
    final userRecipeKeys =
        recipeProvider.userRecipes
            .map(
              (r) => '${r.title.toLowerCase()}|${r.description.toLowerCase()}',
            )
            .toSet();

    final recipeKey =
        '${recipe.title.toLowerCase()}|${recipe.description.toLowerCase()}';
    final isAlreadySaved =
        userRecipeIds.contains(recipe.id) || userRecipeKeys.contains(recipeKey);

    if (isAlreadySaved) {
      // Remove from collection - find the actual user recipe ID
      Recipe? userRecipe = recipeProvider.userRecipes.firstWhere(
        (r) =>
            r.id == recipe.id ||
            (r.title.toLowerCase() == recipe.title.toLowerCase() &&
                r.description.toLowerCase() ==
                    recipe.description.toLowerCase()),
        orElse: () => Recipe(), // Return empty recipe if not found
      );

      if (userRecipe.id.isNotEmpty) {
        final success = await recipeProvider.deleteUserRecipe(
          userRecipe.id,
          context,
        );
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recipe removed from your collection!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } else {
      // Save to collection using RecipeProvider
      final savedRecipe = await recipeProvider.createUserRecipe(
        recipe,
        context,
      );
      if (savedRecipe != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Recipe saved to your collection!'),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Go to My Recipes',
                onPressed: () {
                  if (mounted) {
                    Navigator.pushNamed(context, '/myRecipes');
                  }
                },
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          // Check if it's a duplicate error or other error
          if (recipeProvider.error != null) {
            final errorMessage =
                recipeProvider.error!.message ?? 'Failed to save recipe';
            final isDuplicate = errorMessage.contains('already exists');

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: isDuplicate ? Colors.orange : Colors.red,
              ),
            );
            recipeProvider.clearError();
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
              // Compact filter bar
              CompactFilterBar(
                searchController: _searchController,
                searchQuery: _searchQuery,
                selectedDifficulty: _selectedDifficulty,
                selectedTag: _selectedTag,
                difficulties: _difficulties,
                availableTags: _availableTags,
                onSearchChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _currentPage = 1;
                  });
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (_searchQuery == value) {
                      _loadRecipes();
                    }
                  });
                },
                onDifficultySelected: (difficulty) {
                  setState(() {
                    _selectedDifficulty = difficulty;
                    _currentPage = 1;
                  });
                  _loadRecipes();
                },
                onTagSelected: (tag) {
                  setState(() {
                    _selectedTag = tag;
                    _currentPage = 1;
                  });
                  _loadRecipes();
                },
                onResetFilters: _resetFilters,
                showResetButton:
                    _selectedDifficulty != 'All' ||
                    _selectedTag != 'All' ||
                    _searchQuery.isNotEmpty,
              ),

              // Main content area
              Expanded(
                child: Consumer<RecipeProvider>(
                  builder: (context, recipeProvider, _) {
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

                    final allRecipes = recipeProvider.generatedRecipes;

                    // Server now handles deduplication, so we can use recipes directly
                    final displayRecipes = allRecipes;

                    // Keep all recipes but track which ones are already saved
                    final userRecipeIds =
                        recipeProvider.userRecipes.map((r) => r.id).toSet();
                    final userRecipeKeys =
                        recipeProvider.userRecipes
                            .map(
                              (r) =>
                                  '${r.title.toLowerCase()}|${r.description.toLowerCase()}',
                            )
                            .toSet();

                    // Helper function to check if a recipe is already saved
                    bool isRecipeSaved(Recipe recipe) {
                      final recipeKey =
                          '${recipe.title.toLowerCase()}|${recipe.description.toLowerCase()}';
                      return userRecipeIds.contains(recipe.id) ||
                          userRecipeKeys.contains(recipeKey);
                    }

                    if (!recipeProvider.isLoading && displayRecipes.isEmpty) {
                      return Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 64,
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No recipes found',
                                    style:
                                        Theme.of(
                                          context,
                                        ).textTheme.headlineLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Try adjusting your search or filters',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.responsive(context),
                        AppSpacing.responsive(context),
                        AppSpacing.responsive(context),
                        0,
                      ),
                      child: Column(
                        children: [
                          // Recipe grid with loading overlay
                          Expanded(
                            child: Stack(
                              children: [
                                GridView.builder(
                                  key: const PageStorageKey('discover_grid'),
                                  controller: _scrollController,
                                  padding: EdgeInsets.only(bottom: 100),
                                  itemBuilder: (context, index) {
                                    final recipe = displayRecipes[index];
                                    return RecipeCard(
                                      recipe: recipe,
                                      showSaveButton: !isRecipeSaved(recipe),
                                      showRemoveButton: isRecipeSaved(recipe),
                                      onSave: () => _handleRecipeAction(recipe),
                                      onRemove:
                                          () => _handleRecipeAction(recipe),
                                    );
                                  },
                                  itemCount: displayRecipes.length,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount:
                                            AppSizing.responsiveGridCount(
                                              context,
                                            ),
                                        childAspectRatio:
                                            AppSizing.responsiveAspectRatio(
                                              context,
                                            ),
                                        crossAxisSpacing: AppSpacing.responsive(
                                          context,
                                        ),
                                        mainAxisSpacing: AppSpacing.responsive(
                                          context,
                                        ),
                                      ),
                                ),

                                // Loading overlay only on the recipe grid
                                if (recipeProvider.isLoading)
                                  Container(
                                    color: Theme.of(context).colorScheme.surface
                                        .withValues(alpha: 0.8),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          CircularProgressIndicator(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Loading recipes...',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium?.copyWith(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Pagination bar - always visible
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          Consumer<RecipeProvider>(
            builder: (context, recipeProvider, _) {
              return FloatingBottomBar(
                showPagination: true,
                currentPage: _currentPage,
                totalPages: recipeProvider.totalPages,
                hasNextPage: recipeProvider.hasNextPage,
                hasPreviousPage: recipeProvider.hasPrevPage,
                isLoading: recipeProvider.isLoading,
                onPreviousPage: _goToPreviousPage,
                onNextPage: _goToNextPage,
              );
            },
          ),
        ],
      ),
    );
  }
}
