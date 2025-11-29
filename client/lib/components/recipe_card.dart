import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:recipease/providers/recipe_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/recipe.dart';
import '../utils/snackbar_helper.dart';
import 'package:provider/provider.dart';
import '../services/recipe_service.dart';
import '../theme/theme.dart';
import '../utils/image_utils.dart';
// import 'expandable_image.dart';
import 'smart_recipe_image.dart';
import '../services/google_image_service.dart';
import '../services/collection_service.dart';
import '../services/debug_settings.dart';
import '../models/recipe_collection.dart';

class RecipeCard extends StatefulWidget {
  final Recipe recipe;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final bool showRemoveButton;
  final bool showSaveButton;
  final VoidCallback? onSave;
  final double? aspectRatio;
  final bool showCookingTime;
  final bool showServings;
  final bool showEditButton;
  final bool showRefreshButton;
  // Favorites removed
  final bool showShareButton;
  final Function(Recipe)? onRecipeUpdated;
  final bool showUserAttribution; // Show user who shared the recipe
  final bool
  compactMode; // Compact mode for community cards (hides some details)

  const RecipeCard({
    super.key,
    required this.recipe,
    this.onTap,
    this.onRemove,
    this.showRemoveButton = false,
    this.showSaveButton = false,
    this.onSave,
    this.aspectRatio,
    this.showCookingTime = true,
    this.showServings = true,
    this.showEditButton = false,
    this.showRefreshButton = true,
    this.showShareButton = true,
    this.onRecipeUpdated,
    this.showUserAttribution = false,
    this.compactMode = false,
  });

  @override
  State<RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<RecipeCard> {
  bool _isShareLoading = false;
  bool _isRefreshingImage = false;
  bool _isUpdatingDiscoverImage = false; // Prevent duplicate requests
  final _debugSettings = DebugSettings();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _refreshRecipeImage() async {
    if (_isRefreshingImage) return;

    setState(() {
      _isRefreshingImage = true;
    });

    try {
      // Trigger refresh by fetching a new image from Google
      // Use start: 4 to get a different image from the search results
      final newImageUrl = await GoogleImageService.fetchImageForQuery(
        '${widget.recipe.title} recipe',
        start: 4,
      );

      if (newImageUrl != null &&
          newImageUrl.isNotEmpty &&
          newImageUrl != widget.recipe.imageUrl) {
        // Use the existing onRefreshed callback logic to update the recipe
        final updated = widget.recipe.copyWith(imageUrl: newImageUrl);
        if (widget.onRecipeUpdated != null) {
          widget.onRecipeUpdated!(updated);
        }

        if (mounted) {
          // Update user recipe if applicable
          try {
            final profile = context.read<RecipeProvider>();
            if (widget.showRemoveButton) {
              final userRecipe = profile.userRecipes.firstWhere(
                (r) =>
                    r.id == widget.recipe.id ||
                    (r.title.toLowerCase() ==
                            widget.recipe.title.toLowerCase() &&
                        r.description.toLowerCase() ==
                            widget.recipe.description.toLowerCase()),
                orElse: () => Recipe(),
              );
              if (userRecipe.id.isNotEmpty) {
                await profile.updateUserRecipe(
                  userRecipe.copyWith(imageUrl: newImageUrl),
                );
              }
            }
          } catch (_) {
            // Silently handle errors
          }
        }

        // Update discover recipe if applicable (debug features enabled only, with deduplication)
        if (_debugSettings.shouldShowDebugFeature() &&
            widget.recipe.id.isNotEmpty &&
            !_isUpdatingDiscoverImage) {
          _isUpdatingDiscoverImage = true;
          try {
            await RecipeService.updateDiscoverRecipeImage(
              recipeId: widget.recipe.id,
              imageUrl: newImageUrl,
            );
          } catch (_) {
            // Silently handle errors
          } finally {
            if (mounted) {
              _isUpdatingDiscoverImage = false;
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh image: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingImage = false;
        });
      }
    }
  }

  Future<void> _shareRecipe() async {
    if (_isShareLoading) return;

    setState(() => _isShareLoading = true);
    try {
      // Calculate share origin rect (needed for iPad popover; safe elsewhere)
      final renderBox = context.findRenderObject() as RenderBox?;
      final origin =
          renderBox != null
          ? renderBox.localToGlobal(Offset.zero) & renderBox.size
          : const Rect.fromLTWH(0, 0, 1, 1);

      final String shareText = '''
${widget.recipe.title}

Description:
${widget.recipe.description}

Cooking Time: ${widget.recipe.cookingTime} minutes
Servings: ${widget.recipe.servings}
Difficulty: ${widget.recipe.difficulty}

Ingredients:
${widget.recipe.ingredients.map((i) => '• $i').join('\n')}

Instructions:
${widget.recipe.instructions.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}

${widget.recipe.tags.isNotEmpty ? 'Tags: ${widget.recipe.tags.join(', ')}' : ''}

Shared from RecipEase
''';

      await Share.share(shareText, sharePositionOrigin: origin);

      // Track share for community recipes (not user's own)
      if (widget.showUserAttribution && widget.recipe.id.isNotEmpty) {
        // Fire and forget - don't block the UI
        RecipeService.trackRecipeShare(widget.recipe.id)
            .then((response) {
              if (kDebugMode && response.success) {
                debugPrint('✅ Share tracked for recipe ${widget.recipe.id}');
              }
            })
            .catchError((e) {
              // Silently ignore errors - share tracking is not critical
              if (kDebugMode) {
                debugPrint('⚠️ Failed to track share: $e');
              }
            });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing recipe: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isShareLoading = false);
      }
    }
  }

  Future<void> _deleteRecipe() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Recipe'),
            content: Text(
              'Are you sure you want to delete "${widget.recipe.title}"? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true && mounted) {
      final profile = context.read<RecipeProvider>();
      await profile.deleteUserRecipe(widget.recipe.id, context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recipe "${widget.recipe.title}" deleted'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                final response = await RecipeService.createUserRecipe(
                  widget.recipe,
                );
                if (response.success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Recipe restored'),
                      backgroundColor: Theme.of(context).colorScheme.success,
                    ),
                  );
                }
              },
              textColor: Theme.of(context).colorScheme.surface.withValues(
                alpha: Theme.of(context).colorScheme.alphaVeryHigh,
              ),
            ),
          ),
        );
      }
    }
  }

  /// Builds user attribution row showing contributors (stacked avatars + names)
  Widget _buildUserAttribution(BuildContext context) {
    final users = widget.recipe.sharedByUsers;
    final sharedByCount = widget.recipe.sharedByCount;
    final iconSize = AppSizing.responsiveIconSize(
      context,
      mobile: 20,
      tablet: 22,
      desktop: 24,
    );
    final smallIconSize = AppSizing.responsiveIconSize(
      context,
      mobile: 12,
      tablet: 14,
      desktop: 16,
    );

    // Build stacked avatars (show up to 3)
    Widget buildStackedAvatars() {
      // If no sharedByUsers, fallback to single user
      if (users.isEmpty) {
        return _buildSingleAvatar(
          photoUrl: widget.recipe.sharedByPhotoUrl,
          iconSize: iconSize,
          smallIconSize: smallIconSize,
        );
      }

      final displayUsers = users.take(3).toList();
      final overlapOffset = iconSize * 0.6;

      return SizedBox(
        width: iconSize + (overlapOffset * (displayUsers.length - 1).clamp(0, 2)),
        height: iconSize,
        child: Stack(
          children: [
            for (int i = 0; i < displayUsers.length; i++)
              Positioned(
                left: i * overlapOffset,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).cardColor,
                      width: 1.5,
                    ),
                  ),
                  child: _buildSingleAvatar(
                    photoUrl: displayUsers[i].photoUrl,
                    iconSize: iconSize - 3, // Slightly smaller to account for border
                    smallIconSize: smallIconSize - 2,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // Build attribution text
    String buildAttributionText() {
      if (users.isEmpty) {
        return widget.recipe.sharedByDisplayName ?? 'Chef';
      }

      final names = users
          .take(2)
          .map((u) => u.displayName ?? 'Chef')
          .toList();

      if (sharedByCount <= 1) {
        return names.first;
      } else if (sharedByCount == 2) {
        return names.join(' & ');
      } else {
        final othersCount = sharedByCount - 2;
        return '${names.join(', ')} +$othersCount';
      }
    }

    return Row(
      children: [
        buildStackedAvatars(),
        SizedBox(
          width: AppSpacing.responsive(
            context,
            mobile: 4,
            tablet: 5,
            desktop: 6,
          ),
        ),
        Expanded(
          child: Text(
            buildAttributionText(),
            style: TextStyle(
              fontSize: AppTypography.responsiveFontSize(
                context,
                mobile: 12.0,
                tablet: 13.0,
                desktop: 14.0,
              ),
              fontWeight: widget.compactMode ? FontWeight.w500 : FontWeight.normal,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(
                    widget.compactMode ? 0.9 : 0.7,
                  ),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Builds a single avatar with photo or fallback icon
  Widget _buildSingleAvatar({
    String? photoUrl,
    required double iconSize,
    required double smallIconSize,
  }) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          photoUrl,
          width: iconSize,
          height: iconSize,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildFallbackAvatar(iconSize, smallIconSize);
          },
        ),
      );
    }
    return _buildFallbackAvatar(iconSize, smallIconSize);
  }

  /// Builds fallback avatar with person icon
  Widget _buildFallbackAvatar(double iconSize, double smallIconSize) {
    return Container(
      width: iconSize,
      height: iconSize,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person,
        size: smallIconSize,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    Color? iconColor,
    bool isLoading = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(
          AppBreakpoints.isMobile(context) ? 12 : 16,
        ),
        child: Container(
          padding: EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.3),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(
              AppBreakpoints.isMobile(context) ? 12 : 16,
            ),
          ),
          child:
              isLoading
                  ? SizedBox(
                    width: AppSizing.responsiveIconSize(
                      context,
                      mobile: 14,
                      tablet: 16,
                      desktop: 18,
                    ),
                    height: AppSizing.responsiveIconSize(
                      context,
                      mobile: 14,
                      tablet: 16,
                      desktop: 18,
                    ),
                    child: CircularProgressIndicator(
                      strokeWidth: AppBreakpoints.isMobile(context) ? 1.5 : 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  )
                  : Icon(
                    icon,
                    color: iconColor ?? Theme.of(context).colorScheme.primary,
                    size: AppSizing.responsiveIconSize(
                      context,
                      mobile: 14,
                      tablet: 16,
                      desktop: 18,
                    ),
                  ),
        ),
      ),
    );
  }

  Widget _buildRecipeInfo() {
    if (!widget.showCookingTime && !widget.showServings) {
      return const SizedBox.shrink();
    }

    // Universal icon and text sizes for recipe card details
    final iconSize = AppSizing.responsiveIconSize(
      context,
      mobile: 16,
      tablet: 18,
      desktop: 20,
    );
    final textStyle = TextStyle(
      fontSize: AppTypography.responsiveFontSize(
        context,
        mobile: 12.0,
        tablet: 13.0,
        desktop: 14.0,
      ),
      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: AppBreakpoints.isDesktop(context) ? 6 : 4),
        child: Wrap(
        spacing: AppSpacing.responsive(
          context,
          mobile: 16,
          tablet: 12,
          desktop: 12,
        ),
        runSpacing: AppBreakpoints.isDesktop(context) ? 4 : 4,
          children: [
            if (widget.showCookingTime)
              Row(
              mainAxisSize: MainAxisSize.max,
                children: [
                  Icon(
                    Icons.timer_rounded,
                  size: iconSize,
                  color: Theme.of(
                      context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  SizedBox(width: AppSpacing.xs),
                Text(
                      _formatCookingTime(widget.recipe.cookingTime),
                  style: textStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            if (widget.showServings)
              Row(
              mainAxisSize: MainAxisSize.max,
                children: [
                  Icon(
                    Icons.people,
                  size: iconSize,
                  color: Theme.of(
                      context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  SizedBox(width: AppSpacing.xs),
                Text(
                  _formatServings(widget.recipe.servings),
                  style: textStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            Row(
            mainAxisSize: MainAxisSize.max,
              children: [
                Icon(
                  Icons.restaurant_menu_rounded,
                size: iconSize,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                SizedBox(width: AppSpacing.xs),
              Text(
                    widget.recipe.difficulty,
                style: textStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
      ),
    );
  }

  String _formatCookingTime(String cookingTime) {
    // Clean up the cooking time string - remove words like "approximately", "about", "around", etc.
    String cleaned = cookingTime.toLowerCase().trim();

    // Remove common qualifiers that cause overflow
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\b(approximately|about|around|roughly|nearly|almost|over|under|up to|at least|at most)\b\s*',
        caseSensitive: true,
      ),
      '',
    );

    // Extract numeric value and time unit
    // Pattern: number followed by optional space and time unit (min, minute, minutes, hr, hour, hours, h, m)
    final timePattern = RegExp(
      r'(\d+)\s*(min|minute|minutes|hr|hour|hours|h|m)\b',
      caseSensitive: true,
    );
    final match = timePattern.firstMatch(cleaned);

    if (match != null) {
      final number = int.tryParse(match.group(1) ?? '');
      final unit = match.group(2)?.toLowerCase() ?? '';

      if (number != null) {
        // Normalize the unit
        if (unit.contains('hour') || unit == 'hr' || unit == 'h') {
          // Handle hours
          if (number == 1) {
            return '1 hour';
          } else {
            return '$number hours';
          }
        } else if (unit.contains('minute') || unit == 'min' || unit == 'm') {
          // Handle minutes
          if (number == 1) {
            return '1 minute';
          } else {
            return '$number minutes';
          }
        }
      }
    }

    // Try to parse as pure integer (assume minutes)
    int? minutes = int.tryParse(cookingTime.trim());
    if (minutes != null) {
      if (minutes >= 60) {
        int hours = minutes ~/ 60;
        int remainingMinutes = minutes % 60;
        if (remainingMinutes == 0) {
          return '$hours hour${hours > 1 ? 's' : ''}';
        } else {
          return '$hours hour${hours > 1 ? 's' : ''} $remainingMinutes min${remainingMinutes > 1 ? 's' : ''}';
        }
      } else {
        return '$minutes minute${minutes > 1 ? 's' : ''}';
      }
    }

    // Default case: just append 'minutes' if it's a number-like string
    if (RegExp(r'^\d+$').hasMatch(cookingTime.trim())) {
      return '${cookingTime.trim()} minutes';
    }

    // If we can't parse it, return cleaned version (without qualifiers)
    return cleaned.isEmpty ? cookingTime : cleaned;
  }

  String _formatServings(String servings) {
    if (servings.isEmpty) return '';

    // Clean up the servings string - remove words like "approximately", "about", "around", etc.
    String cleaned = servings.toLowerCase().trim();

    // Remove common qualifiers that cause overflow
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\b(approximately|about|around|roughly|nearly|almost|over|under|up to|at least|at most)\b\s*',
        caseSensitive: false,
      ),
      '',
    );

    // Remove symbols: parentheses, dashes, commas, etc. and everything after them
    // This handles cases like "3 sizes (Small, Medium, Large)" -> "3 sizes"
    cleaned = cleaned.replaceAll(
      RegExp(r'[\(\)\[\]{}]'),
      ' ',
    ); // Remove brackets/parentheses
    cleaned =
        cleaned
            .split(RegExp(r'[,\-–—]'))[0]
            .trim(); // Take only first part before commas/dashes

    // Extract number and determine if it's "servings" or "sizes"
    final numberPattern = RegExp(r'(\d+)');
    final match = numberPattern.firstMatch(cleaned);

    if (match != null) {
      final number = match.group(1) ?? '';

      // Check if the text contains "size" or "serving"
      final hasSize = RegExp(r'\bsize', caseSensitive: false).hasMatch(cleaned);

      // Determine the unit - prefer "sizes" if found, otherwise default to "servings"
      String unit;
      if (hasSize) {
        unit = int.parse(number) == 1 ? 'size' : 'sizes';
      } else {
        unit = int.parse(number) == 1 ? 'serving' : 'servings';
      }

      return '$number $unit';
    }

    // If we can't parse a number, try to return cleaned version
    // Remove any remaining symbols and extra words
    cleaned = cleaned.replaceAll(RegExp(r'[^\w\s]'), ''); // Remove all symbols
    cleaned =
        cleaned.replaceAll(RegExp(r'\s+'), ' ').trim(); // Normalize whitespace

    // If it's just a number, add "servings"
    if (RegExp(r'^\d+$').hasMatch(cleaned)) {
      final num = int.parse(cleaned);
      return '$num ${num == 1 ? 'serving' : 'servings'}';
    }

    // Last resort: return cleaned version if it's not empty
    return cleaned.isNotEmpty ? cleaned : servings;
  }

  Future<RecipeCollection?> _showCreateCollectionDialog() async {
    final TextEditingController nameController = TextEditingController();
    
    final name = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
        title: const Text('Create Collection'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Collection Name',
            hintText: 'Enter collection name',
          ),
          autofocus: true,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.pop(context, value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = nameController.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    
    if (name == null || name.isEmpty || !mounted) return null;
    
    try {
      final collectionService = CollectionService();
      final newCollection = await collectionService.createCollection(name);
      
      if (newCollection != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created collection "$name"'),
            backgroundColor: Colors.green,
          ),
        );
        return newCollection;
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create collection'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    
    return null;
  }

  Future<void> _showAddToCollectionDialog() async {
    final collectionService = CollectionService();
    
    try {
      // Fetch all collections
      final collections = await collectionService.getCollections();
      
      if (!mounted) return;
      
      if (collections.isEmpty) {
        SnackBarHelper.showWarning(
          context,
          'No collections found. Create one first!',
        );
        return;
      }
      
      // Show dialog to select collection or create new
      final result = await showDialog<dynamic>(
        context: context,
        builder:
            (context) => AlertDialog(
          title: const Text('Add to Collection'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Create new collection button
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Create New Collection',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, 'create_new'),
                ),
                const Divider(),
                // Existing collections list
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: collections.length,
                    itemBuilder: (context, index) {
                      final collection = collections[index];
                      // Skip default collections like "Recently Added"
                          if (collection.name == 'Recently Added')
                            return const SizedBox.shrink();
                      
                      return ListTile(
                        leading: Container(
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
                        title: Text(collection.name),
                            subtitle: Text(
                              '${collection.recipes.length} recipes',
                            ),
                        onTap: () => Navigator.pop(context, collection),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      
      if (result == null || !mounted) return;
      
      // Handle create new collection
      if (result == 'create_new') {
        final newCollection = await _showCreateCollectionDialog();
        if (newCollection != null && mounted) {
          // Show loading indicator
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text('Adding recipe to "${newCollection.name}"...'),
                ],
              ),
              duration: const Duration(seconds: 2),
            ),
          );
          
          // Wait a moment for server to fully process the collection creation
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Add recipe to the newly created collection
          // Note: addRecipeToCollection already calls updateCollections, so no need to call it here
          final success = await collectionService.addRecipeToCollection(
            newCollection.id,
            widget.recipe,
          );
          
          // Clear loading snackbar
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
          }
          
          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Added to "${newCollection.name}"'),
                backgroundColor: Colors.green,
                action: SnackBarAction(
                  label: 'View',
                  textColor: Colors.white,
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/collectionDetail',
                      arguments: newCollection,
                    );
                  },
                ),
              ),
            );
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Created "${newCollection.name}" but failed to add recipe',
                ),
                backgroundColor: Colors.orange,
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: () async {
                    final retry = await collectionService.addRecipeToCollection(
                      newCollection.id,
                      widget.recipe,
                    );
                    if (retry && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Successfully added to "${newCollection.name}"',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),
              ),
            );
          }
        }
        return;
      }
      
      // Handle existing collection selection
      final selectedCollection = result as RecipeCollection;
      
      // Show loading indicator immediately
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Text('Adding to "${selectedCollection.name}"...'),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      // Add recipe to collection
      final success = await collectionService.addRecipeToCollection(
        selectedCollection.id,
        widget.recipe,
      );
      
      // Clear loading snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
      
      if (success && mounted) {
        SnackBarHelper.showSuccess(
          context,
          'Added to "${selectedCollection.name}"',
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/collectionDetail',
                  arguments: selectedCollection,
                );
              },
          ),
        );
      } else if (mounted) {
        SnackBarHelper.showError(context, 'Failed to add recipe to collection');
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Error: $e');
      }
    }
  }

  Future<void> _openSourceUrl() async {
    if (widget.recipe.sourceUrl == null || widget.recipe.sourceUrl!.isEmpty) {
      if (mounted) {
        SnackBarHelper.showWarning(
          context,
          'No source URL available for this recipe',
        );
      }
      return;
    }

    try {
      final uri = Uri.parse(widget.recipe.sourceUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          SnackBarHelper.showError(context, 'Could not open source URL');
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Error opening URL: $e');
      }
    }
  }

  bool _isRecipeSaved() {
    // Use listen: true so this widget rebuilds when userRecipes change
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: true);
    final userRecipes = recipeProvider.userRecipes;

    // Check by ID
    if (userRecipes.any((r) => r.id == widget.recipe.id)) return true;

    // Check by sourceUrl
    if (widget.recipe.sourceUrl != null &&
        widget.recipe.sourceUrl!.isNotEmpty) {
      if (userRecipes.any((r) => r.sourceUrl == widget.recipe.sourceUrl))
        return true;
    }

    // Check by title + description
    final recipeKey =
        '${widget.recipe.title.toLowerCase()}|${widget.recipe.description.toLowerCase()}';

    return userRecipes.any(
      (r) =>
          '${r.title.toLowerCase()}|${r.description.toLowerCase()}' ==
          recipeKey,
    );
  }

  Future<void> _toggleLike() async {
    if (widget.recipe.id.isEmpty) {
      if (mounted) {
        SnackBarHelper.showWarning(context, 'Cannot like this recipe');
      }
      return;
    }

    try {
      final recipeProvider = Provider.of<RecipeProvider>(
        context,
        listen: false,
      );
      await recipeProvider.toggleRecipeLike(widget.recipe.id, context);

      // Update the recipe in the widget if onRecipeUpdated is provided
      if (widget.onRecipeUpdated != null) {
        final updatedRecipe = widget.recipe.copyWith(
          isLiked: !widget.recipe.isLiked,
          likeCount:
              widget.recipe.isLiked
                  ? widget.recipe.likeCount - 1
                  : widget.recipe.likeCount + 1,
        );
        widget.onRecipeUpdated!(updatedRecipe);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showRecipeContextMenu(Offset position) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    // Check if this is a community recipe
    final isCommunityRecipe =
        widget.showUserAttribution && widget.recipe.sharedByDisplayName != null;

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              Icon(
                Icons.visibility_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              const Text('View Details'),
            ],
          ),
          onTap: () {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (!mounted) return;
              Navigator.pushNamed(
                context,
                '/recipeDetail',
                arguments: widget.recipe,
              );
            });
          },
        ),
        if (widget.showSaveButton && widget.onSave != null)
          PopupMenuItem(
            child: Row(
              children: [
                Icon(
                  Icons.bookmark_add_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Save Recipe',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            onTap: () {
              Future.delayed(const Duration(milliseconds: 100), () {
                widget.onSave!();
              });
            },
          ),
        // Community-specific options
        if (isCommunityRecipe &&
            widget.recipe.sourceUrl != null &&
            widget.recipe.sourceUrl!.isNotEmpty)
          PopupMenuItem(
            child: Row(
              children: [
                Icon(
                  Icons.open_in_new_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Open Original Source',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            onTap: () {
              Future.delayed(const Duration(milliseconds: 100), () {
                _openSourceUrl();
              });
            },
          ),
        if (isCommunityRecipe)
          PopupMenuItem(
            child: Row(
              children: [
                Icon(
                  widget.recipe.isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_outline_rounded,
                  size: 20,
                  color:
                      widget.recipe.isLiked
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
                Text(
                  widget.recipe.isLiked ? 'Unlike Recipe' : 'Like Recipe',
                  style: TextStyle(
                    color:
                        widget.recipe.isLiked
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.onSurface,
                    fontWeight:
                        widget.recipe.isLiked
                            ? FontWeight.w600
                            : FontWeight.normal,
                  ),
                ),
              ],
            ),
            onTap: () {
              Future.delayed(const Duration(milliseconds: 100), () {
                _toggleLike();
              });
            },
          ),
        if (!widget.showSaveButton && widget.recipe.id.isNotEmpty)
          PopupMenuItem(
            child: Row(
              children: [
                Icon(
                  Icons.folder_copy_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
                const Text('Add to Collection'),
              ],
            ),
            onTap: () {
              Future.delayed(const Duration(milliseconds: 100), () {
                _showAddToCollectionDialog();
              });
            },
          ),
        if (widget.showEditButton || widget.recipe.id.isNotEmpty)
          PopupMenuItem(
            child: Row(
              children: [
                Icon(
                  Icons.edit_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
                const Text('Edit Recipe'),
              ],
            ),
            onTap: () {
              Future.delayed(const Duration(milliseconds: 100), () {
                if (!mounted) return;
                Navigator.pushNamed(
                  context,
                  '/editRecipe',
                  arguments: widget.recipe,
                );
              });
            },
          ),
        if (widget.showShareButton)
          PopupMenuItem(
            child: Row(
              children: [
                Icon(
                  Icons.share_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
                const Text('Share Recipe'),
              ],
            ),
            onTap: () {
              Future.delayed(const Duration(milliseconds: 100), () {
                _shareRecipe();
              });
            },
          ),
        if (widget.showRemoveButton && widget.onRemove != null)
          PopupMenuItem(
            child: Row(
              children: [
                Icon(
                  Icons.remove_circle_outline_rounded,
                  size: 20,
                  color: Colors.orange,
                ),
                const SizedBox(width: 12),
                Text(
                  'Remove from Collection',
                  style: TextStyle(color: Colors.orange),
                ),
              ],
            ),
            onTap: () {
              Future.delayed(const Duration(milliseconds: 100), () {
                widget.onRemove!();
              });
            },
          ),
        // Only show Refresh Image when debug features are enabled
        if (_debugSettings.shouldShowDebugFeature() &&
            (widget.showRefreshButton || widget.recipe.id.isNotEmpty))
          PopupMenuItem(
            child: Row(
              children: [
                Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
                const Text('Refresh Image'),
              ],
            ),
            onTap: () {
              Future.delayed(const Duration(milliseconds: 100), () {
                _refreshRecipeImage();
              });
            },
          ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onLongPressStart: (details) {
        _showRecipeContextMenu(details.globalPosition);
      },
      child: Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AppBreakpoints.isMobile(context) ? 12 : 16,
        ),
      ),
      elevation: AppElevation.responsive(context),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/recipeDetail',
            arguments: widget.recipe,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe image
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: widget.aspectRatio ?? 3 / 2,
                  child: Container(
                    padding: EdgeInsets.all(AppSpacing.xs),
                    child: SmartRecipeImage(
                      key: ValueKey(
                        'smart-img-${widget.recipe.id.isNotEmpty ? widget.recipe.id : widget.recipe.title.toLowerCase()}',
                      ),
                      recipeTitle: widget.recipe.title,
                      primaryImageUrl:
                          ImageUtils.isValidImageUrl(widget.recipe.imageUrl)
                              ? widget.recipe.imageUrl
                              : null,
                      fallbackStaticUrl: ImageUtils.getDefaultRecipeImage(
                        widget.recipe.cuisineType,
                      ),
                      fit: BoxFit.cover,

                      onRefreshStart: () {
                        // no-op in card for now
                      },
                      onRefreshed: (newUrl) async {
                        if (newUrl == null || newUrl.isEmpty) return;
                        if (newUrl == widget.recipe.imageUrl) return;
                        final updated = widget.recipe.copyWith(
                          imageUrl: newUrl,
                        );
                        if (widget.onRecipeUpdated != null) {
                          widget.onRecipeUpdated!(updated);
                        }
                        try {
                          final profile = context.read<RecipeProvider>();
                          if (widget.showRemoveButton) {
                            final userRecipe = profile.userRecipes.firstWhere(
                              (r) =>
                                  r.id == widget.recipe.id ||
                                  (r.title.toLowerCase() ==
                                          widget.recipe.title.toLowerCase() &&
                                      r.description.toLowerCase() ==
                                          widget.recipe.description
                                              .toLowerCase()),
                              orElse: () => Recipe(),
                            );
                            if (userRecipe.id.isNotEmpty) {
                              await profile.updateUserRecipe(
                                userRecipe.copyWith(imageUrl: newUrl),
                              );
                            }
                          }
                        } catch (_) {}
                        // Only update discover recipes when debug features are enabled
                          if (_debugSettings.shouldShowDebugFeature() &&
                              widget.recipe.id.isNotEmpty) {
                          try {
                            await RecipeService.updateDiscoverRecipeImage(
                              recipeId: widget.recipe.id,
                              imageUrl: newUrl,
                            );
                          } catch (_) {}
                        }
                      },
                      onResolvedUrl: (url) async {
                        if (url.isEmpty || url == widget.recipe.imageUrl) {
                          return;
                        }
                        final updated = widget.recipe.copyWith(imageUrl: url);
                        if (widget.onRecipeUpdated != null) {
                          widget.onRecipeUpdated!(updated);
                        }

                        // Persist change appropriately depending on context
                        // 1) If this card represents a saved user recipe, update the user recipe
                        //    Use the actual user recipe id when possible to avoid 403s
                        try {
                          final profile = context.read<RecipeProvider>();
                          if (widget.showRemoveButton) {
                            // Attempt to find the matching user recipe id
                            final userRecipe = profile.userRecipes.firstWhere(
                              (r) =>
                                  r.id == widget.recipe.id ||
                                  (r.title.toLowerCase() ==
                                          widget.recipe.title.toLowerCase() &&
                                      r.description.toLowerCase() ==
                                          widget.recipe.description
                                              .toLowerCase()),
                              orElse: () => Recipe(),
                            );
                            if (userRecipe.id.isNotEmpty) {
                              await profile.updateUserRecipe(
                                userRecipe.copyWith(imageUrl: url),
                              );
                            }
                          }
                        } catch (_) {
                          // Swallow errors here to avoid surfacing a global error overlay
                        }

                        // 2) Update the discover record only when debug features enabled and if URL has changed
                          if (_debugSettings.shouldShowDebugFeature() &&
                              widget.recipe.id.isNotEmpty &&
                              url != widget.recipe.imageUrl) {
                          try {
                            await RecipeService.updateDiscoverRecipeImage(
                              recipeId: widget.recipe.id,
                              imageUrl: url,
                            );
                          } catch (_) {
                            // Ignore discover update failures silently in UI
                          }
                        }
                      },
                      placeholder: const Center(
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.restaurant,
                          size: AppSizing.responsiveIconSize(
                            context,
                            mobile: 40,
                            tablet: 48,
                            desktop: 56,
                          ),
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      cacheKey:
                          widget.recipe.id.isNotEmpty
                              ? 'discover-${widget.recipe.id}'
                              : 'discover-${widget.recipe.title.toLowerCase()}-${widget.recipe.description.toLowerCase()}',
                    ),
                  ),
                ),
                // Action buttons overlay (edit & refresh only in context menu)
                Positioned(
                  top: 8,
                  right: 6,
                  child: Row(
                    children: [
                      if (widget.showShareButton)
                        _buildActionButton(
                          icon: Icons.share_rounded,
                          onTap: _shareRecipe,
                          tooltip: 'Share recipe',
                          isLoading: _isShareLoading,
                        ),
                      if (widget.showShareButton &&
                          (widget.showRemoveButton || widget.showSaveButton))
                        SizedBox(width: AppSpacing.xs),
                      if (widget.showRemoveButton)
                        _buildActionButton(
                          icon: Icons.remove_circle_outline,
                          onTap: widget.onRemove ?? _deleteRecipe,
                          tooltip: 'Remove recipe',
                        ),
                      if (widget.showRemoveButton && widget.showSaveButton)
                        SizedBox(width: AppSpacing.xs),
                      if (widget.showSaveButton && widget.onSave != null)
                        _buildActionButton(
                            icon:
                                _isRecipeSaved()
                                    ? Icons.remove_circle_outline_rounded
                                    : Icons.bookmark_add_rounded,
                          onTap: widget.onSave!,
                            tooltip:
                                _isRecipeSaved()
                                    ? 'Remove recipe'
                                    : 'Save recipe',
                            iconColor: _isRecipeSaved() ? Colors.orange : null,
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // Recipe details
              Expanded(
                child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.responsive(
                  context,
                      mobile: widget.compactMode ? 12 : 16,
                      tablet: widget.compactMode ? 14 : 16,
                      desktop: widget.compactMode ? 16 : 20,
                ),
                AppSpacing.responsive(
                  context,
                      mobile: widget.compactMode ? 12 : 16,
                      tablet: widget.compactMode ? 12 : 14,
                      desktop: widget.compactMode ? 14 : 16,
                ),
                AppSpacing.responsive(
                  context,
                      mobile: widget.compactMode ? 12 : 16,
                      tablet: widget.compactMode ? 14 : 16,
                      desktop: widget.compactMode ? 16 : 20,
                ),
                AppSpacing.responsive(
                  context,
                      mobile: widget.compactMode ? 12 : 14,
                      tablet: widget.compactMode ? 12 : 14,
                      desktop: widget.compactMode ? 14 : 16,
                ),
              ),
              child: Column(
                    mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.recipe.title,
                    style: TextStyle(
                      fontSize: AppTypography.responsiveHeadingSize(
                        context,
                            mobile: widget.compactMode ? 15.0 : 16.0,
                            tablet: widget.compactMode ? 18.0 : 19.0,
                            desktop: widget.compactMode ? 20.0 : 22.0,
                      ),
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: AppBreakpoints.isMobile(context) ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                      // User attribution for community recipes (prominent in compact mode)
                      // Show for all community recipes, with fallback to "Chef" if no display name
                      if (widget.showUserAttribution)
                        Padding(
                          padding: EdgeInsets.only(
                            top: AppSpacing.responsive(
                              context,
                              mobile: widget.compactMode ? 6 : 4,
                              tablet: widget.compactMode ? 8 : 6,
                              desktop: widget.compactMode ? 10 : 8,
                            ),
                          ),
                          child: _buildUserAttribution(context),
                        ),
                      // Spacer to push metrics to bottom in compact mode
                      if (widget.compactMode && widget.showUserAttribution)
                        const Spacer(),
                      // Engagement metrics for community recipes (compact mode)
                      if (widget.compactMode && widget.showUserAttribution)
                        Row(
                          children: [
                            // Likes count (tappable in compact mode)
                            GestureDetector(
                              onTap: () {
                                if (widget.showUserAttribution) {
                                  _toggleLike();
                                }
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    widget.recipe.isLiked
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_outline_rounded,
                                    // Universal icon size (20/22/24) matching profile photo
                                    size: AppSizing.responsiveIconSize(
                                      context,
                                      mobile: 20,
                                      tablet: 22,
                                      desktop: 24,
                                    ),
                                    color:
                                        widget.recipe.isLiked
                                            ? Theme.of(
                                              context,
                                            ).colorScheme.error
                                            : Theme.of(context)
                                                .colorScheme
                                                .error
                                                .withOpacity(0.7),
                                  ),
                                  SizedBox(
                                    width: AppSpacing.responsive(
                                      context,
                                      mobile: 4,
                                      tablet: 5,
                                      desktop: 6,
                                    ),
                                  ),
                                  Text(
                                    '${widget.recipe.likeCount > 0 ? widget.recipe.likeCount : 0}',
                                    style: TextStyle(
                                      fontSize:
                                          AppTypography.responsiveFontSize(
                                            context,
                                            mobile: 12.0,
                                            tablet: 13.0,
                                            desktop: 14.0,
                                          ),
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: AppSpacing.responsive(
                                context,
                                mobile: 12,
                                tablet: 14,
                                desktop: 16,
                              ),
                            ),
                            // Save count (tappable in compact mode for community recipes)
                            GestureDetector(
                              onTap: () {
                                if (widget.showUserAttribution &&
                                    widget.onSave != null) {
                                  widget.onSave!();
                                }
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isRecipeSaved()
                                        ? Icons.bookmark_rounded
                                        : Icons.bookmark_outline_rounded,
                                    // Universal icon size (20/22/24) matching profile photo
                                    size: AppSizing.responsiveIconSize(
                                      context,
                                      mobile: 20,
                                      tablet: 22,
                                      desktop: 24,
                                    ),
                                    color:
                                        _isRecipeSaved()
                                            ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                            : Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withOpacity(0.7),
                                  ),
                                  SizedBox(
                                    width: AppSpacing.responsive(
                                      context,
                                      mobile: 4,
                                      tablet: 5,
                                      desktop: 6,
                                    ),
                                  ),
                                  Text(
                                    '${widget.recipe.saveCount > 0 ? widget.recipe.saveCount : 0}',
                                    style: TextStyle(
                                      fontSize:
                                          AppTypography.responsiveFontSize(
                                            context,
                                            mobile: 12.0,
                                            tablet: 13.0,
                                            desktop: 14.0,
                                          ),
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                ],
                              ),
                            ),
                            SizedBox(
                              width: AppSpacing.responsive(
                                context,
                                mobile: 12,
                                tablet: 14,
                                desktop: 16,
                              ),
                            ),
                            // Share count (tappable to share recipe)
                            GestureDetector(
                              onTap: () {
                                if (widget.showUserAttribution) {
                                  _shareRecipe();
                                }
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.share_rounded,
                                    // Universal icon size (20/22/24) matching profile photo
                                    size: AppSizing.responsiveIconSize(
                                      context,
                                      mobile: 20,
                                      tablet: 22,
                                      desktop: 24,
                                    ),
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.7),
                                  ),
                                  SizedBox(
                                    width: AppSpacing.responsive(
                                      context,
                                      mobile: 4,
                                      tablet: 5,
                                      desktop: 6,
                                    ),
                                  ),
                                  Text(
                                    '${widget.recipe.shareCount > 0 ? widget.recipe.shareCount : 0}',
                                    style: TextStyle(
                                      fontSize:
                                          AppTypography.responsiveFontSize(
                                            context,
                                            mobile: 12.0,
                                            tablet: 13.0,
                                            desktop: 14.0,
                                          ),
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      // Only show recipe info (cooking time, servings) if not in compact mode
                      if (!widget.compactMode) _buildRecipeInfo(),
                    ],
                  ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
