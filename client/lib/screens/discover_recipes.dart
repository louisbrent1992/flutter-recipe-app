import 'package:flutter/material.dart';
import 'dart:async';
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
  final String? initialQuery;
  final String? initialDifficulty;
  final String? initialTag;

  const DiscoverRecipesScreen({
    super.key,
    this.initialQuery,
    this.initialDifficulty,
    this.initialTag,
  });

  @override
  State<DiscoverRecipesScreen> createState() => _DiscoverRecipesScreenState();
}

class _DiscoverRecipesScreenState extends State<DiscoverRecipesScreen>
    with RecipeFilterMixin {
  final ScrollController _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  String _selectedDifficulty = 'All';
  String _selectedTag = 'All';
  int _currentPage = 1;
  static const int _itemsPerPage = 12;
  final List<String> _difficulties = ['All', 'Easy', 'Medium', 'Hard'];
  final List<String> _availableTags = ['All'];

  @override
  void initState() {
    super.initState();
    // Seed initial filters if provided via widget parameters
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchQuery = widget.initialQuery!.trim();
      _searchController.text = _searchQuery;
    }
    if (widget.initialDifficulty != null &&
        widget.initialDifficulty!.isNotEmpty) {
      _selectedDifficulty = widget.initialDifficulty!;
      if (!_difficulties.contains(_selectedDifficulty)) {
        _selectedDifficulty = 'All';
      }
    }
    if (widget.initialTag != null && widget.initialTag!.isNotEmpty) {
      _selectedTag = widget.initialTag!;
      if (!_availableTags.contains(_selectedTag)) {
        // Insert custom tag right after 'All' to make it visible
        _availableTags.insert(1, _selectedTag);
      }
    }

    // Load recipes after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecipes();
    });
  }

  // Build popular tags from the current discover recipe results
  void _updateAvailableTagsFromRecipes() {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    final recipes = recipeProvider.generatedRecipes;

    final Map<String, int> tagCounts = {};
    final Map<String, String> lowerToDisplay = {};

    for (final recipe in recipes) {
      for (final rawTag in recipe.tags) {
        final trimmed = rawTag.trim();
        if (trimmed.isEmpty) continue;
        final key = trimmed.toLowerCase();
        tagCounts[key] = (tagCounts[key] ?? 0) + 1;
        lowerToDisplay.putIfAbsent(key, () => trimmed);
      }
    }

    // Sort tags by frequency (desc) then alphabetically
    final sortedKeys =
        tagCounts.keys.toList()..sort((a, b) {
          final countDiff = (tagCounts[b] ?? 0) - (tagCounts[a] ?? 0);
          if (countDiff != 0) return countDiff;
          return a.compareTo(b);
        });

    final popularTags = sortedKeys.map((k) => lowerToDisplay[k]!).toList();

    // Construct final list with 'All' prefixed
    final newAvailable = <String>['All', ...popularTags];

    // Ensure initial selected tag stays visible even if not among popular
    if (_selectedTag != 'All' && !newAvailable.contains(_selectedTag)) {
      newAvailable.insert(1, _selectedTag);
    }

    // Only update state if changed to avoid unnecessary rebuilds
    if (newAvailable.join('|') != _availableTags.join('|')) {
      setState(() {
        _availableTags
          ..clear()
          ..addAll(newAvailable);
      });
    }
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
    _updateAvailableTagsFromRecipes();
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
    _searchDebounce?.cancel();
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
                  // Debounce server fetches until typing pauses
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 1000),
                    () {
                      if (!mounted) return;
                      if (_searchQuery == value) {
                        _loadRecipes();
                      }
                    },
                  );
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

                    // Friendly empty state: show when not loading and no results
                    if (!recipeProvider.isLoading && displayRecipes.isEmpty) {
                      final parts = <String>[];
                      if (_selectedTag != 'All') {
                        parts.add('tag "$_selectedTag"');
                      }
                      if (_selectedDifficulty != 'All') {
                        parts.add('difficulty "$_selectedDifficulty"');
                      }
                      if (_searchQuery.isNotEmpty) {
                        parts.add('search "$_searchQuery"');
                      }
                      final contextLine =
                          parts.isEmpty ? '' : ' for ${parts.join(' · ')}';

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
                                    'No recipes found$contextLine',
                                    textAlign: TextAlign.center,
                                    style:
                                        Theme.of(
                                          context,
                                        ).textTheme.headlineLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Try a different tag, change filters, or clear filters to see more.',
                                    textAlign: TextAlign.center,
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

                    // Show errors after empty-state check so genuine results absence doesn't look like a network issue
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
                                    // Use a stable key so Flutter does not reuse state across pages
                                    final String identity =
                                        recipe.id.isNotEmpty
                                            ? recipe.id
                                            : '${recipe.title.toLowerCase()}|${recipe.description.toLowerCase()}';
                                    return RecipeCard(
                                      key: ValueKey('discover-card-$identity'),
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
                                            'Fetching delicious recipes for you...',
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
