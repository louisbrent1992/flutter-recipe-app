import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:recipease/components/custom_app_bar.dart';
import '../theme/theme.dart';
import '../components/pull_to_refresh_hint.dart';

import 'package:recipease/models/recipe.dart';
import 'package:recipease/models/recipe_collection.dart';
import 'package:recipease/services/collection_service.dart';
import 'package:recipease/screens/add_recipes_to_collection_screen.dart';
import '../components/recipe_card.dart';

class CollectionDetailScreen extends StatefulWidget {
  final RecipeCollection collection;

  const CollectionDetailScreen({super.key, required this.collection});

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animationController;
  late RecipeCollection _collection;
  late ScrollController _scrollController;
  late TextEditingController _searchController;
  bool _isLoading = false;
  List<Recipe> _filteredRecipes = [];
  String _searchQuery = '';
  late CollectionService _collectionService;

  @override
  void initState() {
    super.initState();
    _collectionService = CollectionService();
    // Don't fetch collection here - use the one passed in widget.collection
    // Only fetch if we need to refresh (e.g., after returning from another screen)
    _collection = widget.collection;
    _scrollController = ScrollController();
    _searchController = TextEditingController();
    _filteredRecipes = _collection.recipes;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();

    // Add observer for app lifecycle events
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh collection when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _refreshCollection();
    }
  }

  void _filterRecipes(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredRecipes = _collection.recipes;
      } else {
        _filteredRecipes =
            _collection.recipes.where((recipe) {
              return recipe.title.toLowerCase().contains(_searchQuery) ||
                  recipe.description.toLowerCase().contains(_searchQuery) ||
                  recipe.ingredients.any(
                    (i) => i.toLowerCase().contains(_searchQuery),
                  ) ||
                  recipe.tags.any(
                    (t) => t.toLowerCase().contains(_searchQuery),
                  );
            }).toList();
      }
    });
  }

  Future<void> _refreshCollection() async {
    setState(() => _isLoading = true);
    try {
      // Try getCollection which will use cached/local storage first (works offline)
      // This will return the cached collection immediately if available
      final updatedCollection = await _collectionService.getCollection(
        _collection.id,
      );
      if (updatedCollection != null && mounted) {
        setState(() {
          _collection = updatedCollection;
          _filteredRecipes = _collection.recipes;
          _filterRecipes(_searchQuery);
        });
      } else {
        // If getCollection fails, at least update filtered recipes from current collection
        setState(() {
          _filteredRecipes = _collection.recipes;
          _filterRecipes(_searchQuery);
        });
      }
    } catch (e) {
      // On error, just update filtered recipes from current collection
      setState(() {
        _filteredRecipes = _collection.recipes;
        _filterRecipes(_searchQuery);
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editCollection() async {
    final TextEditingController nameController = TextEditingController(
      text: _collection.name,
    );
    final theme = Theme.of(context);

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Collection'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoTextField(
                  controller: nameController,
                  placeholder: 'Enter collection name',
                  autofocus: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.outline,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                  ),
                  placeholderStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('More editing options coming soon!'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    return;
                  }
                  Navigator.pop(context, {'name': name});
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );

    if (result != null && mounted) {
      setState(() => _isLoading = true);
      try {
        final updatedCollection = await _collectionService.updateCollection(
          _collection.id,
          name: result['name'],
        );

        if (updatedCollection != null && mounted) {
          setState(() => _collection = updatedCollection);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Collection updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating collection: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _removeRecipe(Recipe recipe) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Remove Recipe'),
            content: Text(
              'Are you sure you want to remove "${recipe.title}" from this collection?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(
                    alpha: Theme.of(context).colorScheme.alphaVeryHigh,
                  ),
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final success = await _collectionService.removeRecipeFromCollection(
          _collection.id,
          recipe.id,
        );

        if (success) {
          await _refreshCollection();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Removed "${recipe.title}" from collection'),
                backgroundColor: Colors.orange,
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () async {
                    await _collectionService.addRecipeToCollection(
                      _collection.id,
                      recipe,
                    );
                    await _refreshCollection();
                  },
                  textColor: Colors.white,
                ),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error removing recipe: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _searchAllRecipes() async {
    // Navigate to the recipe search screen and pass the collection
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => AddRecipesToCollectionScreen(collection: _collection),
      ),
    );

    // Refresh the collection if we got results back
    if (result == true && mounted) {
      await _refreshCollection();
    }
  }

  Future<void> _deleteCollection() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Collection'),
            content: Text(
              'Are you sure you want to delete "${_collection.name}"? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final success = await _collectionService.deleteCollection(
          _collection.id,
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted "${_collection.name}"'),
              backgroundColor: Colors.red,
            ),
          );
          // Navigate back to the previous screen
          Navigator.pop(context, true);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete collection'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting collection: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  // Helper method to check if a collection is a default collection
  bool _isDefaultCollection(RecipeCollection collection) {
    return collection.name == 'Recently Added';
  }

  // Helper method to get a contrasting icon color for better visibility
  Color _getIconColor(Color collectionColor) {
    // Calculate brightness of the collection color
    final brightness = collectionColor.computeLuminance();

    // If the color is light (brightness > 0.5), use a darker, more saturated version
    // If the color is dark (brightness <= 0.5), use a lighter version or white
    if (brightness > 0.5) {
      // For light colors, use a darker, more saturated version
      final hsl = HSLColor.fromColor(collectionColor);
      return hsl
          .withLightness((hsl.lightness * 0.4).clamp(0.0, 1.0))
          .withSaturation((hsl.saturation * 1.3).clamp(0.0, 1.0))
          .toColor();
    } else {
      // For dark colors, use a lighter, more vibrant version
      final hsl = HSLColor.fromColor(collectionColor);
      return hsl
          .withLightness((hsl.lightness * 1.8).clamp(0.0, 1.0))
          .withSaturation((hsl.saturation * 1.2).clamp(0.0, 1.0))
          .toColor();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: CustomAppBar(
        title: _collection.name,
        actions: [
          if (!_isDefaultCollection(_collection))
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
                          const Text('Refresh Collection'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            size: 20,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(width: 12),
                          const Text('Edit Collection'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'add',
                      child: Row(
                        children: [
                          Icon(
                            Icons.add_rounded,
                            size: 20,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(width: 12),
                          const Text('Add Recipes'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Delete Collection',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
              onSelected: (value) {
                switch (value) {
                  case 'refresh':
                    _refreshCollection();
                    break;
                  case 'edit':
                    _editCollection();
                    break;
                  case 'add':
                    _searchAllRecipes();
                    break;
                  case 'delete':
                    _deleteCollection();
                    break;
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Stack(
        children: [
          // Main content
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicatorWithHint(
                onRefresh: _refreshCollection,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Collection header
                    SliverToBoxAdapter(
                      child: _buildCollectionHeader(colorScheme),
                    ),

                    // Search field
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: AppSpacing.responsive(context),
                          right: AppSpacing.responsive(context),
                          top: AppSpacing.responsive(context) * 0.5,
                          bottom: AppSpacing.responsive(context) + 30, // Extra space for floating bar
                        ),
                        child: _buildSearchField(colorScheme),
                      ),
                    ),

                    // Recipes grid
                    _filteredRecipes.isEmpty
                        ? SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.no_meals,
                                  size: AppSizing.responsiveIconSize(
                                    context,
                                    mobile: 64,
                                    tablet: 80,
                                    desktop: 96,
                                  ),
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                                SizedBox(
                                  height:
                                      AppBreakpoints.isDesktop(context)
                                          ? 24
                                          : AppBreakpoints.isTablet(context)
                                          ? 20
                                          : 16,
                                ),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'No recipes in this collection yet'
                                      : 'No recipes match your search',
                                  style: TextStyle(
                                    fontSize: AppTypography.responsiveFontSize(
                                      context,
                                      mobile: 16,
                                      tablet: 18,
                                      desktop: 20,
                                    ),
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        : SliverPadding(
                          padding: EdgeInsets.all(
                            AppSpacing.responsive(context),
                          ),
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: AppSizing.responsiveGridCount(
                                    context,
                                  ),
                                  childAspectRatio:
                                      AppSizing.responsiveAspectRatio(context),
                                  crossAxisSpacing: AppSpacing.responsive(
                                    context,
                                  ),
                                  mainAxisSpacing: AppSpacing.responsive(
                                    context,
                                  ),
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final recipe = _filteredRecipes[index];
                              return RecipeCard(
                                recipe: recipe,
                                showEditButton: true,
                                onTap:
                                    () => Navigator.pushNamed(
                                      context,
                                      '/recipeDetail',
                                      arguments: recipe,
                                    ),
                                showRemoveButton:
                                    !_isDefaultCollection(_collection),
                                onRemove: () => _removeRecipe(recipe),
                                showRefreshButton: true,
                                onRecipeUpdated: (updatedRecipe) {
                                  // Refresh collection when recipe is updated
                                  _refreshCollection();
                                },
                              );
                            }, childCount: _filteredRecipes.length),
                          ),
                        ),
                  ],
                ),
              ),
        ],
        ),
      ),
    );
  }

  Widget _buildCollectionHeader(ColorScheme colorScheme) {
    final responsivePadding = AppSpacing.responsive(context);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _animationController.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _animationController.value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.fromLTRB(
          responsivePadding,
          responsivePadding,
          responsivePadding,
          responsivePadding * 0.5,
        ),
        padding: EdgeInsets.all(
          AppBreakpoints.isDesktop(context)
              ? 24
              : AppBreakpoints.isTablet(context)
              ? 20
              : 16,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            AppBreakpoints.isDesktop(context)
                ? 20
                : AppBreakpoints.isTablet(context)
                ? 18
                : 16,
          ),
          color: _collection.color.withValues(alpha: 0.2),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(
                AppBreakpoints.isDesktop(context)
                    ? 16
                    : AppBreakpoints.isTablet(context)
                    ? 14
                    : 12,
              ),
              decoration: BoxDecoration(
                color: _collection.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(
                  AppBreakpoints.isDesktop(context)
                      ? 16
                      : AppBreakpoints.isTablet(context)
                      ? 14
                      : 12,
                ),
              ),
              child: Icon(
                _collection.icon,
                size: AppSizing.responsiveIconSize(
                  context,
                  mobile: 32,
                  tablet: 40,
                  desktop: 48,
                ),
                color: _getIconColor(_collection.color),
              ),
            ),
            SizedBox(
              width:
                  AppBreakpoints.isDesktop(context)
                      ? 20
                      : AppBreakpoints.isTablet(context)
                      ? 18
                      : 16,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _collection.name,
                    style: TextStyle(
                      fontSize: AppTypography.responsiveHeadingSize(
                        context,
                        mobile: 22,
                        tablet: 26,
                        desktop: 30,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(
                    height:
                        AppBreakpoints.isDesktop(context)
                            ? 6
                            : AppBreakpoints.isTablet(context)
                            ? 5
                            : 4,
                  ),
                  Text(
                    '${_collection.recipes.length} ${_collection.recipes.length == 1 ? 'recipe' : 'recipes'}',
                    style: TextStyle(
                      fontSize: AppTypography.responsiveFontSize(
                        context,
                        mobile: 14,
                        tablet: 16,
                        desktop: 18,
                      ),
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(ColorScheme colorScheme) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: (_animationController.value - 0.2).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(
              0,
              20 * (1 - (_animationController.value - 0.2).clamp(0.0, 1.0)),
            ),
            child: child,
          ),
        );
      },
      child: CupertinoTextField(
        controller: _searchController,
        onChanged: _filterRecipes,
        placeholder: 'Search recipes...',
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(
            AppBreakpoints.isDesktop(context)
                ? 16
                : AppBreakpoints.isTablet(context)
                ? 14
                : 12,
          ),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        style: TextStyle(
          color: colorScheme.onSurface,
        ),
        placeholderStyle: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        prefix: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Icon(Icons.search, color: colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
        suffix:
            _searchQuery.isNotEmpty
                ? Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      _filterRecipes('');
                    },
                    child: Icon(Icons.clear, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                )
                : null,
      ),
    );
  }
}
