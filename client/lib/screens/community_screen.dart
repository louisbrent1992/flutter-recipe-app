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
import '../components/inline_banner_ad.dart';
import '../components/offline_banner.dart';
import '../components/pull_to_refresh_hint.dart'; // Provides RefreshIndicatorWithHint

class CommunityScreen extends StatefulWidget {
  final String? initialQuery;
  final String? initialDifficulty;
  final String? initialTag;
  final String? displayQuery;

  const CommunityScreen({
    super.key,
    this.initialQuery,
    this.initialDifficulty,
    this.initialTag,
    this.displayQuery,
  });

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
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
      _searchController.text = widget.displayQuery ?? _searchQuery;
    }
    if (widget.initialDifficulty != null &&
        widget.initialDifficulty!.isNotEmpty) {
      _selectedDifficulty = widget.initialDifficulty!;
      if (!_difficulties.contains(_selectedDifficulty)) {
        _selectedDifficulty = 'All';
      }
    }
    if (widget.initialTag != null && widget.initialTag!.isNotEmpty) {
      _searchQuery = widget.initialTag!.trim();
      _searchController.text = widget.displayQuery ?? _searchQuery;
      _selectedTag = 'All';
    }

    // Load recipes after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final recipeProvider = Provider.of<RecipeProvider>(
        context,
        listen: false,
      );
      recipeProvider.fetchSessionCommunityCache().then((_) {
        _loadRecipes();
      });

      _recipesChangedSubscription = recipeProvider.onRecipesChanged.listen((_) {
        // Don't reload community recipes when user recipes change
      });
    });
  }

  // Build popular tags from the current community recipe results
  void _updateAvailableTagsFromRecipes() {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    final recipes = recipeProvider.communityRecipes;

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

    // Ensure session cache is populated
    await recipeProvider.fetchSessionCommunityCache(forceRefresh: forceRefresh);

    // Filter the cached recipes using all filters
    await recipeProvider.fetchCommunityRecipes(
      query: _searchQuery.isNotEmpty ? _searchQuery : null,
      difficulty: _selectedDifficulty == 'All' ? null : _selectedDifficulty,
      tag: _selectedTag == 'All' ? null : _selectedTag,
      page: _currentPage,
      limit: _itemsPerPage,
      forceRefresh: forceRefresh,
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
    _loadRecipes();
  }

  // Refresh search results
  Future<void> _refreshResults() async {
    await _loadRecipes(forceRefresh: true);
    if (mounted) {
      SnackBarHelper.showInfo(context, 'Community recipes refreshed');
    }
  }

  // Handle page navigation
  void _goToPage(int page) {
    setState(() {
      _currentPage = page;
    });
    _loadRecipes();
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
    final userRecipes = recipeProvider.userRecipes;

    // Check if recipe is already saved (matches RecipeCard._isRecipeSaved logic)
    bool isAlreadySaved = userRecipes.any((r) => r.id == recipe.id);

    // Check by sourceUrl (most reliable for external recipes)
    if (!isAlreadySaved &&
        recipe.sourceUrl != null &&
        recipe.sourceUrl!.isNotEmpty) {
      isAlreadySaved = userRecipes.any((r) => r.sourceUrl == recipe.sourceUrl);
    }

    // Fallback to title + description
    if (!isAlreadySaved) {
      final recipeKey =
          '${recipe.title.toLowerCase()}|${recipe.description.toLowerCase()}';
      isAlreadySaved = userRecipes.any(
        (r) =>
            '${r.title.toLowerCase()}|${r.description.toLowerCase()}' ==
            recipeKey,
      );
    }

    if (isAlreadySaved) {
      // Find the saved recipe using the same logic
      Recipe? userRecipe = userRecipes.firstWhere(
        (r) => r.id == recipe.id,
        orElse: () => Recipe(),
      );

      if (userRecipe.id.isEmpty &&
          recipe.sourceUrl != null &&
          recipe.sourceUrl!.isNotEmpty) {
        userRecipe = userRecipes.firstWhere(
          (r) => r.sourceUrl == recipe.sourceUrl,
          orElse: () => Recipe(),
        );
      }

      if (userRecipe.id.isEmpty) {
        userRecipe = userRecipes.firstWhere(
          (r) =>
              r.title.toLowerCase() == recipe.title.toLowerCase() &&
              r.description.toLowerCase() == recipe.description.toLowerCase(),
          orElse: () => Recipe(),
        );
      }

      if (userRecipe.id.isNotEmpty) {
        final success = await recipeProvider.deleteUserRecipe(
          userRecipe.id,
          context,
        );
        if (success && mounted) {
          // Update save count via provider method for proper encapsulation
          recipeProvider.updateCommunityRecipeSaveCount(recipe.id, -1);

          SnackBarHelper.showWarning(
            context,
            'Recipe removed from your collection!',
          );
        }
      }
    } else {
      // Pass the original recipe ID to track save count
      final originalRecipeId = recipe.id.isNotEmpty ? recipe.id : null;
      final savedRecipe = await recipeProvider.createUserRecipe(
        recipe,
        context,
        originalRecipeId: originalRecipeId,
      );
      if (savedRecipe != null) {
        // Update save count via provider method for proper encapsulation
        recipeProvider.updateCommunityRecipeSaveCount(recipe.id, 1);

        if (mounted) {
          SnackBarHelper.showSuccess(
            context,
            'Recipe saved to your collection!',
            action: SnackBarAction(
              label: 'Go to My Recipes',
              textColor: Colors.white,
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
        title: 'Community',
        fullTitle: 'Community Recipes',
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
                ],
            onSelected: (value) {
              if (value == 'refresh') {
                _refreshResults();
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Show offline banner at top when offline
              const OfflineBanner(),
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

              // Inline banner ad
              const InlineBannerAd(),

              // Main content area
              Expanded(
                child: Consumer<RecipeProvider>(
                  builder: (context, recipeProvider, _) {
                    final displayRecipes = recipeProvider.communityRecipes;

                    if (recipeProvider.error != null &&
                        displayRecipes.isEmpty &&
                        !recipeProvider.isLoading) {
                      final isOffline = recipeProvider.error!.isNetworkError;
                      return ErrorDisplay(
                        message: recipeProvider.error!.userFriendlyMessage,
                        title:
                            isOffline
                                ? 'You\'re Offline'
                                : 'Couldn\'t Load Recipes',
                        subtitle:
                            isOffline
                                ? 'Connect to the internet to browse community recipes'
                                : 'Something went wrong. Please try again.',
                        isNetworkError: isOffline,
                        isAuthError: recipeProvider.error!.isAuthError,
                        isFormatError: recipeProvider.error!.isFormatError,
                        customIcon:
                            isOffline
                                ? Icons.wifi_off_rounded
                                : Icons.cloud_off_rounded,
                        onRetry: () {
                          recipeProvider.clearError();
                          _loadRecipes();
                        },
                      );
                    }

                    if (!recipeProvider.isLoading && displayRecipes.isEmpty) {
                      return RefreshIndicatorWithHint(
                        onRefresh: () async {
                          await _loadRecipes(forceRefresh: true);
                        },
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
                                      Icons.people_outline_rounded,
                                      size: 64,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withValues(alpha: 0.6),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      'No community recipes found',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Try adjusting your filters or check back later',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
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

                    if (recipeProvider.isLoading && displayRecipes.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return Padding(
                      padding: EdgeInsets.only(
                        left: AppSpacing.responsive(context),
                        right: AppSpacing.responsive(context),
                        top: AppSpacing.responsive(context),
                        bottom:
                            AppSpacing.responsive(context) +
                            30, // Extra space for floating bar
                      ),
                      child: RefreshIndicatorWithHint(
                        onRefresh: () async {
                          await _loadRecipes(forceRefresh: true);
                        },
                        child: GridView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.only(
                            bottom: 100, // Extra padding for scroll
                          ),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount:
                                    AppBreakpoints.isDesktop(context)
                                        ? 4
                                        : AppBreakpoints.isTablet(context)
                                        ? 3
                                        : 2,
                                crossAxisSpacing: AppSpacing.responsive(
                                  context,
                                ),
                                mainAxisSpacing: AppSpacing.responsive(context),
                                childAspectRatio: 0.75,
                              ),
                          itemCount: displayRecipes.length,
                          itemBuilder: (context, index) {
                            final recipe = displayRecipes[index];
                            return RecipeCard(
                              recipe: recipe,
                              onSave: () => _handleRecipeAction(recipe),
                              showUserAttribution: true,
                              showSaveButton: true,
                              compactMode: true,
                              showCookingTime: false,
                              showServings: false,
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          // Floating bottom bar with pagination (FloatingBottomBar already handles positioning)
          Consumer<RecipeProvider>(
            builder: (context, recipeProvider, _) {
              return FloatingBottomBar(
                showPagination: recipeProvider.totalPages > 1,
                currentPage: recipeProvider.currentPage,
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
