import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipease/components/custom_app_bar.dart';

import 'package:recipease/models/recipe_collection.dart';
import 'package:recipease/services/collection_service.dart';
import '../theme/theme.dart';

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
      duration: const Duration(milliseconds: 700),
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
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Name Your Collection'),
            elevation: AppElevation.dialog,
            content: Column(
              children: [
                TextField(
                  controller: _categoryNameController,
                  decoration: const InputDecoration(
                    hintText: 'Enter category name',
                    labelText: 'Category Name',
                  ),
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Scaffold(
        appBar: CustomAppBar(
          title: 'Collections',
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
              itemBuilder: (context) => [
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
                : RefreshIndicator(
                  onRefresh: () => _loadCollections(forceRefresh: true),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.responsive(context),
                        AppSpacing.responsive(context),
                        AppSpacing.responsive(context),
                        70,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header section
                          _buildHeader(colorScheme),

                          SizedBox(
                            height: AppBreakpoints.isDesktop(context)
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
                  width: AppBreakpoints.isDesktop(context)
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
                        height: AppBreakpoints.isDesktop(context)
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
          childAspectRatio: AppSizing.responsiveAspectRatio(context),
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
    final cardBorderRadius = AppBreakpoints.isDesktop(context)
        ? 20.0
        : AppBreakpoints.isTablet(context)
            ? 18.0
            : 16.0;

    return Card(
      elevation: AppElevation.responsive(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardBorderRadius),
      ),
      color:
          colorScheme.brightness == Brightness.dark
              ? colorScheme.surface.withValues(alpha: 0.1)
              : colorScheme.surface,

      child: InkWell(
        onTap: () {
          // Navigate to collection detail screen
          Navigator.pushNamed(
            context,
            '/collectionDetail',
            arguments: collection,
          ).then((_) => _loadCollections()); // Refresh after returning
        },
        borderRadius: BorderRadius.circular(cardBorderRadius),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth;

            // Use theme-based responsive sizing
            final iconContainerSize = cardWidth * 0.35;
            final iconSize = AppSizing.responsiveIconSize(
              context,
              mobile: iconContainerSize * 0.4,
              tablet: iconContainerSize * 0.45,
              desktop: iconContainerSize * 0.5,
            );
            final containerPadding = iconContainerSize * 0.15;
            final borderRadius = iconContainerSize * 0.2;

            // Use theme typography
            final titleFontSize = AppTypography.responsiveFontSize(
              context,
              mobile: 14.0,
              tablet: 16.0,
              desktop: 18.0,
            );
            final countFontSize = AppTypography.responsiveCaptionSize(context);
            final countIconSize = AppSizing.responsiveIconSize(
              context,
              mobile: 12.0,
              tablet: 14.0,
              desktop: 16.0,
            );

            // Use theme spacing
            final verticalSpacing =
                AppSpacing.responsive(
                  context,
                  mobile: AppSpacing.xs,
                  tablet: AppSpacing.sm,
                  desktop: AppSpacing.md,
                ) *
                0.5;
            final deleteButtonSize = AppSizing.responsiveIconSize(
              context,
              mobile: 16.0,
              tablet: 18.0,
              desktop: 20.0,
            );

            return Stack(
              children: [
                // Main content
                Padding(
                  padding: AppSizing.responsiveCardPadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Flexible space for icon
                      Expanded(
                        flex: 3,
                        child: Center(
                          child: Container(
                            width: iconContainerSize,
                            height: iconContainerSize,
                            padding: EdgeInsets.all(containerPadding),
                            decoration: BoxDecoration(
                              color: collection.color.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(borderRadius),
                              border: Border.all(
                                color: collection.color.withValues(alpha: 0.5),
                                width:
                                    AppBreakpoints.isMobile(context)
                                        ? 1.5
                                        : 2.0,
                              ),
                            ),
                            child: FittedBox(
                              child: Icon(
                                collection.icon,
                                color: collection.color,
                                size: iconSize,
                              ),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: verticalSpacing),

                      // Collection name - flexible space
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Text(
                            collection.name,
                            style: Theme.of(
                              context,
                            ).textTheme.headlineSmall?.copyWith(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                            maxLines: AppBreakpoints.isMobile(context) ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),

                      SizedBox(height: verticalSpacing),

                      // Recipe count
                      Flexible(
                        flex: 1,
                        child: FittedBox(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.book,
                                size: countIconSize,
                                color: Colors.grey.shade600,
                              ),
                              SizedBox(width: AppSpacing.xs),
                              Text(
                                '${collection.recipes.length} ${collection.recipes.length == 1 ? 'recipe' : 'recipes'}',
                                style: TextStyle(
                                  fontSize: countFontSize,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Delete button positioned absolutely in top right corner
                if (!_isDefaultCollection(collection))
                  Positioned(
                    top: AppBreakpoints.isDesktop(context)
                        ? 12
                        : AppBreakpoints.isTablet(context)
                            ? 10
                            : 8,
                    right: AppBreakpoints.isDesktop(context)
                        ? 12
                        : AppBreakpoints.isTablet(context)
                            ? 10
                            : 8,
                    child: IconButton(
                      icon: Icon(Icons.delete_outline, size: deleteButtonSize),
                      onPressed:
                          () => _deleteCategory(collection.id, collection.name),
                      tooltip: 'Delete category',
                      color: Colors.grey.shade600,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
