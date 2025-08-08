import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:recipease/components/custom_app_bar.dart';
import 'package:recipease/components/floating_bottom_bar.dart';

import 'package:recipease/components/recipe_card.dart';
import 'package:recipease/components/compact_filter_bar.dart';
import 'package:recipease/mixins/recipe_filter_mixin.dart';
import 'package:recipease/screens/favorite_recipes_screen.dart';
import '../providers/recipe_provider.dart';
import '../models/recipe.dart';
import '../theme/theme.dart';

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

  @override
  void initState() {
    super.initState();
    // Initial load of recipes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecipes();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
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
    if (recipeProvider.hasNextPage) {
      _goToPage(_currentPage + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'My Recipes',
        floatingButtons: [
          // Favorite Recipes button
          IconButton(
            icon: const Icon(Icons.favorite_rounded),
            tooltip: 'Favorite Recipes',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FavoriteRecipesScreen(),
                ),
              );
            },
          ),
          // New Recipe button
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Recipe',
            onPressed: () => Navigator.pushNamed(context, '/recipeEdit'),
          ),
        ],
      ),
      body: Column(
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
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          allRecipes.isEmpty
                              ? Icons.restaurant_menu_rounded
                              : Icons.search_off,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          allRecipes.isEmpty
                              ? 'No recipes found'
                              : 'No matching recipes',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (allRecipes.isEmpty)
                          Text(
                            'Add your first recipe to get started',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  );
                }

                return Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: () => _loadRecipes(forceRefresh: true),
                      child: GridView.builder(
                        key: const PageStorageKey('my_recipes_grid'),
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.responsive(context),
                          AppSpacing.responsive(context),
                          AppSpacing.responsive(context),
                          100,
                        ),
                        controller: _scrollController,
                        itemBuilder: (context, index) {
                          final recipe = filteredRecipes[index];
                          return RecipeCard(
                            recipe: recipe,
                            showEditButton: true,
                            showRemoveButton: true,
                            showFavoriteButton: true,
                            onTap:
                                () => Navigator.pushNamed(
                                  context,
                                  '/recipeDetail',
                                  arguments: recipe,
                                ),
                            onRecipeUpdated: (updatedRecipe) {
                              // Update the recipe in the list
                              setState(() {
                                final index = allRecipes.indexWhere(
                                  (r) => r.id == updatedRecipe.id,
                                );
                                if (index != -1) {
                                  allRecipes[index] = updatedRecipe;
                                }
                              });
                            },
                          );
                        },
                        itemCount: filteredRecipes.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: AppSizing.responsiveGridCount(
                            context,
                          ),
                          childAspectRatio: AppSizing.responsiveAspectRatio(
                            context,
                          ),
                          crossAxisSpacing: AppSpacing.responsive(context),
                          mainAxisSpacing: AppSpacing.responsive(context),
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
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Loading recipes...',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Floating bottom bar
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
