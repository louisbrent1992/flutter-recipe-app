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
import '../utils/snackbar_helper.dart';

class DiscoverRecipesScreen extends StatefulWidget {
  final String? initialQuery;
  final String? initialDifficulty;
  final String? initialTag;
  final String? displayQuery;

  const DiscoverRecipesScreen({
    super.key,
    this.initialQuery,
    this.initialDifficulty,
    this.initialTag,
    this.displayQuery,
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

  StreamSubscription<void>? _recipesChangedSubscription;

  @override
  void initState() {
    super.initState();
    // Seed initial filters if provided via widget parameters
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchQuery = widget.initialQuery!.trim();
      // Use displayQuery from server if available, otherwise use actual query
      _searchController.text = widget.displayQuery ?? _searchQuery;
    }
    if (widget.initialDifficulty != null &&
        widget.initialDifficulty!.isNotEmpty) {
      _selectedDifficulty = widget.initialDifficulty!;
      if (!_difficulties.contains(_selectedDifficulty)) {
        _selectedDifficulty = 'All';
      }
    }
    // Treat initialTag as a search query (from notifications/server)
    if (widget.initialTag != null && widget.initialTag!.isNotEmpty) {
      _searchQuery = widget.initialTag!.trim();
      // Use displayQuery from server if available, otherwise use actual query
      _searchController.text = widget.displayQuery ?? _searchQuery;
      _selectedTag = 'All'; // Clear tag filter, use query instead
    }

    // Load recipes after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Fetch session cache first (500 recipes)
      final recipeProvider = Provider.of<RecipeProvider>(
        context,
        listen: false,
      );
      recipeProvider.fetchSessionDiscoverCache().then((_) {
        // After cache is ready, load filtered results
        _loadRecipes();
      });

      // Listen for cross-screen recipe updates to refetch current page
      _recipesChangedSubscription = recipeProvider.onRecipesChanged.listen((_) {
        _loadRecipes();
      });
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

  // Load recipes from session cache (client-side filtering)
  Future<void> _loadRecipes({bool forceRefresh = false}) async {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);

    // Always use client-side filtering on cached 500 recipes (no server requests)
    debugPrint('💾 Using CLIENT-side filtering on cached recipes');
    debugPrint('   UI State: difficulty="${_selectedDifficulty}", tag="${_selectedTag}", query="${_searchQuery}"');
    
    // Ensure session cache is populated (will use existing cache if valid)
    await recipeProvider.fetchSessionDiscoverCache(forceRefresh: forceRefresh);

    // Filter the cached recipes using all filters (query, difficulty, tag)
    final filtered = recipeProvider.getFilteredDiscoverRecipes(
      query: _searchQuery.isNotEmpty ? _searchQuery : null,
      difficulty: _selectedDifficulty == 'All' ? null : _selectedDifficulty,
      tag: _selectedTag == 'All' ? null : _selectedTag,
      page: _currentPage,
      limit: _itemsPerPage,
    );

    // Update generatedRecipes for UI (without notifying again)
    recipeProvider.setGeneratedRecipesFromCache(filtered);

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

  // Refresh search results
  Future<void> _refreshResults() async {
    await _loadRecipes(forceRefresh: true);
    if (mounted) {
      SnackBarHelper.showInfo(context, 'Search results refreshed');
    }
  }

  // Randomize search results from session cache
  Future<void> _randomizeResults() async {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    setState(() {
      _currentPage = 1;
    });

    // Shuffle the session cache
    recipeProvider.randomizeSessionCache();

    // Reload with page 1 to show reshuffled results
    await _loadRecipes();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Showing randomized recipes'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
          SnackBarHelper.showSuccess(
            context,
            'Recipe saved to your collection!',
            action: SnackBarAction(
              label: 'Go to My Recipes',
              onPressed: () {
                if (mounted) {
                  Navigator.pushNamed(context, '/myRecipes');
                }
              },
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

            if (isDuplicate) {
              SnackBarHelper.showWarning(context, errorMessage);
            } else {
              SnackBarHelper.showError(context, errorMessage);
            }
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
    _recipesChangedSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Discover',
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'More options',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder:
                (context) => [
                  PopupMenuItem<String>(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(width: 12),
                        const Text('Refresh Results'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'randomize',
                    child: Row(
                      children: [
                        Icon(
                          Icons.shuffle_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(width: 12),
                        const Text('Randomize Results'),
                      ],
                    ),
                  ),
                ],
            onSelected: (value) {
              switch (value) {
                case 'refresh':
                  _refreshResults();
                  break;
                case 'randomize':
                  _randomizeResults();
                  break;
              }
            },
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
                    // Use tag as search query instead of tag filter
                    if (tag == 'All') {
                      _searchQuery = '';
                      _selectedTag = 'All';
                      _searchController.clear();
                    } else {
                      _searchQuery = tag;
                      _selectedTag = 'All'; // Clear tag filter, use query instead
                      _searchController.text = tag;
                    }
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
                    // Server now handles filtering (excludes current user's recipes)
                    // and deduplication, so we can use recipes directly
                    final displayRecipes = recipeProvider.generatedRecipes;
                    
                    debugPrint('🎨 UI RENDER: ${displayRecipes.length} recipes to display');
                    debugPrint('   Loading: ${recipeProvider.isLoading}, Has error: ${recipeProvider.error != null}');
                    debugPrint('   Search query: "$_searchQuery", Selected tag: "$_selectedTag"');

                    // Friendly empty state: show when not loading and no results
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
                                    size: AppSizing.responsiveIconSize(
                                      context,
                                      mobile: 64,
                                      tablet: 80,
                                      desktop: 96,
                                    ),
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.5),
                                  ),
                                  SizedBox(
                                    height: AppSpacing.responsive(
                                      context,
                                      mobile: 16,
                                      tablet: 20,
                                      desktop: 24,
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: AppSpacing.responsive(
                                        context,
                                      ),
                                    ),
                                    child: Text(
                                      'No recipes found',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: AppSpacing.responsive(
                                      context,
                                      mobile: 8,
                                      tablet: 10,
                                      desktop: 12,
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: AppSpacing.responsive(
                                        context,
                                      ),
                                    ),
                                    child: Text(
                                      'Try adjusting your filters or search terms',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                      ),
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
                                      showSaveButton:
                                          true, // All displayed recipes are unsaved
                                      showRemoveButton:
                                          false, // Saved recipes are filtered out
                                      showRefreshButton: false,
                                      showDeleteButton: false,
                                      onSave: () => _handleRecipeAction(recipe),
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
                                          SizedBox(
                                            width:
                                                AppBreakpoints.isDesktop(
                                                      context,
                                                    )
                                                    ? 48
                                                    : AppBreakpoints.isTablet(
                                                      context,
                                                    )
                                                    ? 44
                                                    : 40,
                                            height:
                                                AppBreakpoints.isDesktop(
                                                      context,
                                                    )
                                                    ? 48
                                                    : AppBreakpoints.isTablet(
                                                      context,
                                                    )
                                                    ? 44
                                                    : 40,
                                            child: CircularProgressIndicator(
                                              strokeWidth:
                                                  AppBreakpoints.isDesktop(
                                                        context,
                                                      )
                                                      ? 4
                                                      : 3,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                            ),
                                          ),
                                          SizedBox(
                                            height: AppSpacing.responsive(
                                              context,
                                              mobile: 16,
                                              tablet: 20,
                                              desktop: 24,
                                            ),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: AppSpacing.responsive(
                                                context,
                                              ),
                                            ),
                                            child: Text(
                                              'Fetching delicious recipes for you...',
                                              style:
                                                  AppBreakpoints.isDesktop(
                                                        context,
                                                      )
                                                      ? Theme.of(context)
                                                          .textTheme
                                                          .bodyLarge
                                                          ?.copyWith(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onSurface,
                                                          )
                                                      : Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onSurface,
                                                          ),
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
