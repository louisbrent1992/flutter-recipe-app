import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipease/components/custom_app_bar.dart';

import 'package:recipease/models/recipe_collection.dart';
import 'package:recipease/models/recipe.dart';
import 'package:recipease/services/collection_service.dart';
import '../theme/theme.dart';
import '../components/inline_banner_ad.dart';
import '../components/pull_to_refresh_hint.dart';

class RecipeCollectionScreen extends StatefulWidget {
  const RecipeCollectionScreen({super.key});

  @override
  State<RecipeCollectionScreen> createState() =>
      _RecipeCollectionsScreenState();
}

class _RecipeCollectionsScreenState extends State<RecipeCollectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final TextEditingController _categoryNameController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  List<RecipeCollection> _collections = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();

    // Load collections
    _loadCollections();
  }

  Future<void> _loadCollections({bool forceRefresh = false}) async {
    final collectionService = Provider.of<CollectionService>(
      context,
      listen: false,
    );
    setState(() => _isLoading = true);

    try {
      // Fetch collections using the service
      final collections = await collectionService.getCollections(
        forceRefresh: forceRefresh,
        updateSpecialCollections:
            forceRefresh, // Only update special collections when explicitly refreshing
      );

      if (mounted) {
        setState(() {
          _collections = collections;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.surface.withValues(
                    alpha: Theme.of(context).colorScheme.alphaVeryHigh,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('Error loading collections: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddCategoryDialog() {
    _categoryNameController.clear();
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Name Your Collection'),
            elevation: AppElevation.dialog,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoTextField(
                  controller: _categoryNameController,
                  placeholder: 'Enter category name',
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
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
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  _addCategory(_categoryNameController.text);
                  Navigator.pop(context);
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  Future<void> _addCategory(String name) async {
    if (name.isEmpty) return;
    final collectionService = Provider.of<CollectionService>(
      context,
      listen: false,
    );

    setState(() => _isLoading = true);

    try {
      final newCollection = await collectionService.createCollection(name);

      if (newCollection != null) {
        // Refresh collections to show the new one
        await _loadCollections();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Category "$name" added'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding category: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteCategory(String id, String name) async {
    final collectionService = Provider.of<CollectionService>(
      context,
      listen: false,
    );
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Collection'),
            content: Text(
              'Are you sure you want to delete the collection "$name"? This action cannot be undone.',
            ),
            contentTextStyle: Theme.of(context).textTheme.bodySmall,
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
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final success = await collectionService.deleteCollection(id);
        if (success) {
          await _loadCollections();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Collection "$name" deleted'),
                backgroundColor: Colors.orange,
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () async {
                    await collectionService.createCollection(name);
                    await _loadCollections();
                  },
                  textColor: Theme.of(context).colorScheme.surface.withValues(
                    alpha: Theme.of(context).colorScheme.alphaVeryHigh,
                  ),
                ),
              ),
            );
          }
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

  @override
  void dispose() {
    _animationController.dispose();
    _categoryNameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Helper method to check if a collection is a default collection
  bool _isDefaultCollection(RecipeCollection collection) {
    // Only "Recently Added" is considered default; "Favorites" is user-created if present
    return collection.name == 'Recently Added';
  }

  // Helper method to get a contrasting icon color for better visibility
  Color _getIconColor(Color collectionColor) {
    // Calculate brightness of the collection color
    final brightness = collectionColor.computeLuminance();

    // If the color is light (brightness > 0.5), use a darker, more saturated version
    // If the color is dark (brightness <= 0.5), use a lighter version
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

  /// Builds a background with recipe images in a grid/collage style
  Widget _buildRecipeImagesBackground(
    List<Recipe> recipes,
    Color fallbackColor,
  ) {
    final imagesToShow = recipes.take(4).toList(); // Show up to 4 images

    if (imagesToShow.length == 1) {
      // Single image fills the entire background
      return Image.network(
        imagesToShow[0].imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildGradientBackground(fallbackColor),
      );
    } else if (imagesToShow.length == 2) {
      // Two images side by side
      return Row(
        children:
            imagesToShow
                .map(
                  (recipe) => Expanded(
                    child: Image.network(
                      recipe.imageUrl,
                      fit: BoxFit.cover,
                      height: double.infinity,
                      errorBuilder:
                          (_, __, ___) => Container(
                            color: fallbackColor.withValues(alpha: 0.3),
                          ),
                    ),
                  ),
                )
                .toList(),
      );
    } else if (imagesToShow.length >= 3) {
      // Grid layout for 3+ images
      return Column(
        children: [
          // Top row - single large image
          Expanded(
            flex: 2,
            child: Image.network(
              imagesToShow[0].imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder:
                  (_, __, ___) =>
                      Container(color: fallbackColor.withValues(alpha: 0.3)),
            ),
          ),
          // Bottom row - smaller images
          Expanded(
            flex: 1,
            child: Row(
              children:
                  imagesToShow
                      .skip(1)
                      .take(2)
                      .map(
                        (recipe) => Expanded(
                          child: Image.network(
                            recipe.imageUrl,
                            fit: BoxFit.cover,
                            height: double.infinity,
                            errorBuilder:
                                (_, __, ___) => Container(
                                  color: fallbackColor.withValues(alpha: 0.3),
                                ),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
        ],
      );
    }

    return _buildGradientBackground(fallbackColor);
  }

  /// Builds a gradient background when no images are available
  Widget _buildGradientBackground(Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.3),
            color.withValues(alpha: 0.7),
            color,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
        appBar: CustomAppBar(
          title: 'Collections',
          fullTitle: 'My Collections',
          floatingButtons: [
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
                  case 'add_collection':
                    _showAddCategoryDialog();
                    break;
                  case 'refresh':
                    await _loadCollections(forceRefresh: true);
                    break;
                }
              },
              itemBuilder:
                  (context) => [
                    PopupMenuItem<String>(
                      value: 'add_collection',
                      child: Row(
                        children: [
                          Icon(
                            Icons.add_rounded,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text('Add Collection'),
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
          fit: StackFit.expand,
          children: [
            // Background aligned to global scaffold background
            Positioned.fill(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
            ),

            // Main content
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicatorWithHint(
                  onRefresh: () => _loadCollections(forceRefresh: true),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: AppSpacing.responsive(context),
                        right: AppSpacing.responsive(context),
                        top: AppSpacing.responsive(context),
                        bottom: AppSpacing.responsive(context) + 30, // Extra space for floating bar
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Inline banner ad between app bar and title banner
                          const InlineBannerAd(),

                          // Header section
                          _buildHeader(colorScheme),

                          SizedBox(
                            height:
                                AppBreakpoints.isDesktop(context)
                                    ? 32
                                    : AppBreakpoints.isTablet(context)
                                    ? 28
                                    : 24,
                          ),

                          // Grid of categories
                          _buildCategoriesGrid(colorScheme),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ),
      );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: (_animationController.value).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(
              0,
              20 * (1 - _animationController.value.clamp(0.0, 1.0)),
            ),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(
              AppBreakpoints.isDesktop(context)
                  ? 24
                  : AppBreakpoints.isTablet(context)
                  ? 22
                  : 20,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                AppBreakpoints.isDesktop(context)
                    ? 20
                    : AppBreakpoints.isTablet(context)
                    ? 18
                    : 16,
              ),
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
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
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      AppBreakpoints.isDesktop(context)
                          ? 16
                          : AppBreakpoints.isTablet(context)
                          ? 14
                          : 12,
                    ),
                  ),
                  child: Icon(
                    Icons.collections_bookmark_rounded,
                    size: AppSizing.responsiveIconSize(
                      context,
                      mobile: 32,
                      tablet: 40,
                      desktop: 48,
                    ),
                    color: colorScheme.primary,
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
                        'Recipe Collections',
                        style: TextStyle(
                          fontSize: AppTypography.responsiveHeadingSize(
                            context,
                            mobile: 22,
                            tablet: 26,
                            desktop: 30,
                          ),
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
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
                        'Organize your recipes into categories',
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
        ],
      ),
    );
  }

  Widget _buildCategoriesGrid(ColorScheme colorScheme) {
    if (_collections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_rounded,
              size: AppSizing.responsiveIconSize(
                context,
                mobile: 48,
                tablet: 56,
                desktop: 64,
              ),
              color: colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            SizedBox(height: AppSpacing.responsive(context)),
            Text(
              'No collections yet',
              style: TextStyle(
                fontSize: AppTypography.responsiveHeadingSize(
                  context,
                  mobile: 16,
                  tablet: 18,
                  desktop: 20,
                ),
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Create your first collection by tapping the + button',
              style: TextStyle(
                fontSize: AppTypography.responsiveFontSize(context),
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: (_animationController.value - 0.2).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(
              0,
              30 * (1 - (_animationController.value - 0.2).clamp(0.0, 1.0)),
            ),
            child: child,
          ),
        );
      },
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: AppSizing.responsiveGridCount(context),
          childAspectRatio:
              0.85, // Aspect ratio that matches the collection card design
          crossAxisSpacing: AppSpacing.responsive(context),
          mainAxisSpacing: AppSpacing.responsive(context),
        ),
        itemCount: _collections.length,
        itemBuilder: (context, index) {
          final collection = _collections[index];

          return _buildCategoryCard(
            collection: collection,
            colorScheme: colorScheme,
          );
        },
      ),
    );
  }

  Widget _buildCategoryCard({
    required RecipeCollection collection,
    required ColorScheme colorScheme,
  }) {
    final theme = Theme.of(context);
    final hasRecipes = collection.recipes.isNotEmpty;
    final recipesWithImages =
        collection.recipes.where((r) => r.imageUrl.isNotEmpty).toList();

    final borderRadius = AppBreakpoints.isDesktop(context) ? 24.0 : 20.0;

    return Stack(
      children: [
        Card(
          elevation: AppBreakpoints.isDesktop(context) ? 6 : 4,
          shadowColor: collection.color.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: InkWell(
            onTap: () {
              // Navigate to collection detail screen
              Navigator.pushNamed(
                context,
                '/collectionDetail',
                arguments: collection,
              ).then((_) => _loadCollections()); // Refresh after returning
            },
            onLongPress:
                !_isDefaultCollection(collection)
                    ? () => _showCollectionContextMenu(collection)
                    : null,
            borderRadius: BorderRadius.circular(borderRadius),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Stack(
                children: [
                  // Background with recipe images or gradient
                  Positioned.fill(
                    child:
                        hasRecipes && recipesWithImages.isNotEmpty
                            ? _buildRecipeImagesBackground(
                              recipesWithImages,
                              collection.color,
                            )
                            : _buildGradientBackground(collection.color),
                  ),

                  // Gradient overlay for text readability
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                          stops: const [0.4, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Collection icon (top-right corner)
                  Positioned(
                    top: AppBreakpoints.isDesktop(context) ? 16 : 12,
                    right: AppBreakpoints.isDesktop(context) ? 16 : 12,
                    child: Container(
                      padding: EdgeInsets.all(
                        AppBreakpoints.isDesktop(context) ? 12 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withValues(
                          alpha: Theme.of(context).colorScheme.alphaVeryHigh,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppBreakpoints.isDesktop(context) ? 16 : 12,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius:
                                AppBreakpoints.isDesktop(context) ? 6 : 4,
                            offset: Offset(
                              0,
                              AppBreakpoints.isDesktop(context) ? 3 : 2,
                            ),
                          ),
                        ],
                      ),
                      child: Icon(
                        collection.icon,
                        size: AppBreakpoints.isDesktop(context) ? 28 : 20,
                        color: _getIconColor(collection.color),
                      ),
                    ),
                  ),

                  // Collection info (bottom)
                  Positioned(
                    left: AppBreakpoints.isDesktop(context) ? 20 : 16,
                    right: AppBreakpoints.isDesktop(context) ? 20 : 16,
                    bottom: AppBreakpoints.isDesktop(context) ? 20 : 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Collection name
                        Text(
                          collection.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              AppBreakpoints.isDesktop(context)
                                  ? theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.5,
                                        ),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  )
                                  : theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.5,
                                        ),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                        ),
                        SizedBox(
                          height: AppBreakpoints.isDesktop(context) ? 6 : 4,
                        ),
                        // Recipe count with icon
                        Row(
                          children: [
                            Icon(
                              Icons.restaurant_menu_rounded,
                              size: AppBreakpoints.isDesktop(context) ? 18 : 14,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                            ),
                            SizedBox(
                              width: AppBreakpoints.isDesktop(context) ? 6 : 4,
                            ),
                            Text(
                              '${collection.recipes.length} ${collection.recipes.length == 1 ? 'recipe' : 'recipes'}',
                              style:
                                  AppBreakpoints.isDesktop(context)
                                      ? theme.textTheme.bodyMedium?.copyWith(
                                        color:
                                            Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                        fontWeight: FontWeight.w500,
                                      )
                                      : theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                        fontWeight: FontWeight.w500,
                                      ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showCollectionContextMenu(RecipeCollection collection) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Collection name header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: collection.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          collection.icon,
                          color: collection.color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          collection.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // Edit option
                ListTile(
                  leading: Icon(
                    Icons.edit_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Edit Collection'),
                  onTap: () {
                    Navigator.pop(context);
                    _editCollection(collection);
                  },
                ),
                // Delete option
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Delete Collection',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteCategory(collection.id, collection.name);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
        );
  }

  Future<void> _editCollection(RecipeCollection collection) async {
    final TextEditingController nameController = TextEditingController(
      text: collection.name,
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
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) {
                    return;
                  }
                  Navigator.pop(context, {'name': nameController.text.trim()});
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );

    // Dispose controller after dialog animation completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
    });

    if (result != null && mounted) {
      final collectionService = Provider.of<CollectionService>(
        context,
        listen: false,
      );

      final updatedCollection = await collectionService.updateCollection(
        collection.id,
        name: result['name'],
      );

      if (updatedCollection != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated "${result['name']}"'),
            backgroundColor: Colors.green,
          ),
        );
        _loadCollections(forceRefresh: true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update collection'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
