import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipease/components/custom_app_bar.dart';
import '../providers/recipe_provider.dart';
import '../components/recipe_card.dart';
import '../components/floating_home_button.dart';
import '../components/compact_filter_bar.dart';
import '../components/pagination_bar.dart';
import '../mixins/recipe_filter_mixin.dart';
import '../models/recipe.dart';
import '../components/error_display.dart';
import '../theme/theme.dart';

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipe saved to your collection!'),
            backgroundColor: Colors.green,
          ),
        );
        // Trigger a rebuild to refresh the filtered list
        setState(() {});
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

                    // First, deduplicate the recipes based on title and description
                    final Map<String, Recipe> uniqueRecipesMap = {};
                    for (final recipe in allRecipes) {
                      final key =
                          '${recipe.title.toLowerCase()}|${recipe.description.toLowerCase()}';
                      if (!uniqueRecipesMap.containsKey(key)) {
                        uniqueRecipesMap[key] = recipe;
                      }
                    }
                    final deduplicatedRecipes =
                        uniqueRecipesMap.values.toList();

                    // Then filter out recipes that are already in user's collection
                    final userRecipeIds =
                        recipeProvider.userRecipes.map((r) => r.id).toSet();
                    final userRecipeKeys =
                        recipeProvider.userRecipes
                            .map(
                              (r) =>
                                  '${r.title.toLowerCase()}|${r.description.toLowerCase()}',
                            )
                            .toSet();

                    final newRecipes =
                        deduplicatedRecipes.where((recipe) {
                          final recipeKey =
                              '${recipe.title.toLowerCase()}|${recipe.description.toLowerCase()}';
                          return !userRecipeIds.contains(recipe.id) &&
                              !userRecipeKeys.contains(recipeKey);
                        }).toList();

                    if (!recipeProvider.isLoading && newRecipes.isEmpty) {
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
                                    allRecipes.isEmpty
                                        ? 'No recipes found'
                                        : 'No new recipes found',
                                    style:
                                        Theme.of(
                                          context,
                                        ).textTheme.headlineLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    allRecipes.isEmpty
                                        ? 'Try adjusting your search or filters'
                                        : 'You\'ve already saved all matching recipes!',
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

                          // Show pagination even when empty (in case of loading)
                          PaginationBar(
                            currentPage: _currentPage,
                            totalPages: recipeProvider.totalPages,
                            hasNextPage: recipeProvider.hasNextPage,
                            hasPreviousPage: recipeProvider.hasPrevPage,
                            isLoading: recipeProvider.isLoading,
                            onPreviousPage: _goToPreviousPage,
                            onNextPage: _goToNextPage,
                            onPageSelected: _goToPage,
                            totalItems: recipeProvider.totalRecipes,
                            itemsPerPage: _itemsPerPage,
                          ),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        // Recipe grid with loading overlay
                        Expanded(
                          child: Stack(
                            children: [
                              Padding(
                                padding: AppSpacing.horizontalResponsive(
                                  context,
                                ),
                                child: GridView.builder(
                                  controller: _scrollController,
                                  itemBuilder: (context, index) {
                                    final recipe = newRecipes[index];
                                    return RecipeCard(
                                      recipe: recipe,
                                      showSaveButton:
                                          true, // Always show save button since these are new recipes
                                      showRemoveButton:
                                          false, // Never show remove button since they're not saved
                                      onSave: () => _handleRecipeAction(recipe),
                                      onRemove:
                                          () => _handleRecipeAction(recipe),
                                    );
                                  },
                                  itemCount: newRecipes.length,
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
                              ),

                              // Loading overlay only on the recipe grid
                              if (recipeProvider.isLoading)
                                Container(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surface.withValues(alpha: 0.8),
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
                        PaginationBar(
                          currentPage: _currentPage,
                          totalPages: recipeProvider.totalPages,
                          hasNextPage: recipeProvider.hasNextPage,
                          hasPreviousPage: recipeProvider.hasPrevPage,
                          isLoading: recipeProvider.isLoading,
                          onPreviousPage: _goToPreviousPage,
                          onNextPage: _goToNextPage,
                          onPageSelected: _goToPage,
                          totalItems: recipeProvider.totalRecipes,
                          itemsPerPage: _itemsPerPage,
                        ),
                      ],
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
