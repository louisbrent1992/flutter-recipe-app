import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:recipease/components/custom_app_bar.dart';
import 'package:recipease/components/floating_bottom_bar.dart';

import 'package:recipease/components/recipe_card.dart';
import 'package:recipease/components/compact_filter_bar.dart';
import 'package:recipease/components/cache_status_indicator.dart';
import 'package:recipease/mixins/recipe_filter_mixin.dart';
import '../providers/recipe_provider.dart';
import '../models/recipe.dart';
import '../theme/theme.dart';
import '../components/inline_banner_ad.dart';
import '../components/pull_to_refresh_hint.dart';

class MyRecipesScreen extends StatefulWidget {
  const MyRecipesScreen({super.key});

  @override
  State<MyRecipesScreen> createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends State<MyRecipesScreen>
    with RecipeFilterMixin {
  final ScrollController _scrollController = ScrollController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDifficulty = 'All';
  String _selectedTag = 'All';
  int _currentPage = 1;
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
  StreamSubscription<void>? _recipesChangedSubscription;

  @override
  void initState() {
    super.initState();
    // Initial load of recipes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecipes();
      // Listen for cross-screen recipe updates to refetch current page
      final recipeProvider = Provider.of<RecipeProvider>(
        context,
        listen: false,
      );
      _recipesChangedSubscription = recipeProvider.onRecipesChanged.listen((_) {
        // Provider already updates userRecipes optimistically via createUserRecipe/deleteUserRecipe
        // Just trigger a rebuild to reflect the changes without network fetch
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _recipesChangedSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadRecipes({bool forceRefresh = false}) async {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    await recipeProvider.loadUserRecipes(
      page: _currentPage,
      forceRefresh: forceRefresh,
    );
    _updateAvailableTags(recipeProvider.userRecipes);
  }

  void _updateAvailableTags(List<Recipe> recipes) {
    final newTags =
        recipes.expand((recipe) => recipe.tags).toSet().toList()..sort();
    if (!listEquals(_availableTags, newTags)) {
      setState(() {
        _availableTags.clear();
        _availableTags.add('All');
        _availableTags.addAll(newTags);
      });
    }
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
    _loadRecipes();
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
    // Check if we can go to the next page based on current page vs total pages
    if (_currentPage < recipeProvider.totalPages) {
      _goToPage(_currentPage + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent, // Transparent background
      extendBody: true, // Extend body behind bottom elements
      appBar: CustomAppBar(
        title: 'Recipes',
        fullTitle: 'My Recipes',
        actions: [
          // Context menu
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: Icon(
              Icons.more_vert,
              size: AppSizing.responsiveIconSize(
                context,
                mobile: 24,
                tablet: 28,
                desktop: 30,
              ),
            ),
            color: Theme.of(context).colorScheme.surface.withValues(
              alpha: Theme.of(context).colorScheme.alphaVeryHigh,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outline.withValues(
                  alpha: Theme.of(context).colorScheme.overlayLight,
                ),
                width: 1,
              ),
            ),
            onSelected: (value) async {
              switch (value) {
                case 'new_recipe':
                  Navigator.pushNamed(context, '/recipeEdit');
                  break;
                case 'refresh':
                  await _loadRecipes(forceRefresh: true);
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  PopupMenuItem<String>(
                    value: 'new_recipe',
                    child: Row(
                      children: [
                        Icon(
                          Icons.add,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text('New Recipe'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(
                          Icons.refresh,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text('Refresh'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
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
                  Future.delayed(const Duration(milliseconds: 300), () {
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

              // Inline banner ad under search bar
              const InlineBannerAd(),

              // Cache status indicator
              const CacheStatusIndicator(
                dataType: 'user_recipes',
                compact: true,
              ),

              // Main content area
              Expanded(
                child: Consumer<RecipeProvider>(
                  builder: (context, recipeProvider, _) {
                    final List<Recipe> allRecipes = recipeProvider.userRecipes;
                    final List<Recipe> filteredRecipes = filterRecipes(
                      allRecipes,
                      searchQuery: _searchQuery,
                      selectedDifficulty: _selectedDifficulty,
                      selectedTag: _selectedTag,
                    );

                    // Update available tags when recipes change
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _updateAvailableTags(allRecipes);
                    });

                    if (!recipeProvider.isLoading && filteredRecipes.isEmpty) {
                      final colorScheme = Theme.of(context).colorScheme;
                      return RefreshIndicatorWithHint(
                        onRefresh: () => _loadRecipes(forceRefresh: true),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.7,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      allRecipes.isEmpty
                                          ? Icons.restaurant_menu_rounded
                                          : Icons.search_off_rounded,
                                      size: 64,
                                      color: colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.6),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      allRecipes.isEmpty
                                          ? 'No recipes yet'
                                          : 'No matching recipes',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      allRecipes.isEmpty
                                          ? 'Add your first recipe to get started'
                                          : 'Try adjusting your search or filters',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.7),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return Padding(
                      padding: EdgeInsets.only(
                        left: AppSpacing.responsive(context),
                        right: AppSpacing.responsive(context),
                        top: AppSpacing.responsive(context),
                        // Bottom padding handled by GridView for scrolling behind bar
                        bottom: 0,
                      ),
                      child: Column(
                        children: [
                          // Recipe grid with loading overlay and pull-to-refresh
                          Expanded(
                            child: Stack(
                              children: [
                                RefreshIndicatorWithHint(
                                  onRefresh:
                                      () => _loadRecipes(forceRefresh: true),
                                  child:
                                      filteredRecipes.isEmpty
                                          ? ListView(
                                            padding: EdgeInsets.only(
                                              bottom: 120 + bottomPadding,
                                            ),
                                          )
                                          : GridView.builder(
                                            key: const PageStorageKey(
                                              'my_recipes_grid',
                                            ),
                                            controller: _scrollController,
                                            // Add padding for bottom bar and safe area
                                            padding: EdgeInsets.only(
                                              bottom: 120 + bottomPadding,
                                            ),
                                            itemBuilder: (context, index) {
                                              final recipe =
                                                  filteredRecipes[index];
                                              return RecipeCard(
                                                recipe: recipe,
                                                showEditButton: false,
                                                showRefreshButton: false,
                                                showRemoveButton: true,
                                                // Favorites removed
                                                onTap: () async {
                                                  final result =
                                                      await Navigator.pushNamed(
                                                        context,
                                                        '/recipeDetail',
                                                        arguments: recipe,
                                                      );
                                                  if (result is Recipe &&
                                                      mounted) {
                                                    setState(() {
                                                      final idx = allRecipes
                                                          .indexWhere(
                                                            (r) =>
                                                                r.id ==
                                                                result.id,
                                                          );
                                                      if (idx != -1) {
                                                        allRecipes[idx] =
                                                            result;
                                                      }
                                                    });
                                                  }
                                                },
                                                onRecipeUpdated: (
                                                  updatedRecipe,
                                                ) {
                                                  // Update the recipe in the list
                                                  setState(() {
                                                    final index = allRecipes
                                                        .indexWhere(
                                                          (r) =>
                                                              r.id ==
                                                              updatedRecipe.id,
                                                        );
                                                    if (index != -1) {
                                                      allRecipes[index] =
                                                          updatedRecipe;
                                                    }
                                                  });
                                                },
                                              );
                                            },
                                            itemCount: filteredRecipes.length,
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
                                                  crossAxisSpacing:
                                                      AppSpacing.responsive(
                                                        context,
                                                      ),
                                                  mainAxisSpacing:
                                                      AppSpacing.responsive(
                                                        context,
                                                      ),
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
                                            'Fetching your tasty recipes...',
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
                onGoToPage: _goToPage,
              );
            },
          ),
        ],
      ),
    );
  }
}
