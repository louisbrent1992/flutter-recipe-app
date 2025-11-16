import 'package:flutter/material.dart';
import 'package:recipease/providers/recipe_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/recipe.dart';
import 'package:provider/provider.dart';
import '../services/recipe_service.dart';
import '../theme/theme.dart';
import '../utils/image_utils.dart';
// import 'expandable_image.dart';
import 'smart_recipe_image.dart';

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
  // Favorites removed
  final bool showShareButton;
  final bool showDeleteButton; // Developer-only delete button
  final VoidCallback? onDelete; // Callback for delete action
  final Function(Recipe)? onRecipeUpdated;

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
    this.showShareButton = true,
    this.showDeleteButton = false,
    this.onDelete,
    this.onRecipeUpdated,
  });

  @override
  State<RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<RecipeCard> {
  bool _isShareLoading = false;

  @override
  void initState() {
    super.initState();
  }

  // Refresh button removed from cards

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

Shared from Recipe App
''';

      await Share.share(shareText, sharePositionOrigin: origin);
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
                  size: AppSizing.responsiveIconSize(
                    context,
                    mobile: 12,
                    tablet: 14,
                    desktop: 16,
                  ),
                  color: Colors.grey[600],
                ),
                SizedBox(width: AppSpacing.xs),
                Text(
                  _formatCookingTime(widget.recipe.cookingTime),
                  style: TextStyle(
                    fontSize: AppTypography.responsiveCaptionSize(context),
                    color: Colors.grey[600],
                  ),
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
                  size: AppSizing.responsiveIconSize(
                    context,
                    mobile: 12,
                    tablet: 14,
                    desktop: 16,
                  ),
                  color: Colors.grey[600],
                ),
                SizedBox(width: AppSpacing.xs),
                Text(
                  _formatServings(widget.recipe.servings),
                  style: TextStyle(
                    fontSize: AppTypography.responsiveCaptionSize(context),
                    color: Colors.grey[600],
                  ),
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
                size: AppSizing.responsiveIconSize(
                  context,
                  mobile: 12,
                  tablet: 14,
                  desktop: 16,
                ),
                color: Colors.grey[600],
              ),
              SizedBox(width: AppSpacing.xs),
              Text(
                widget.recipe.difficulty,
                style: TextStyle(
                  fontSize: AppTypography.responsiveCaptionSize(context),
                  color: Colors.grey[600],
                ),
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
    cleaned = cleaned.replaceAll(RegExp(r'[\(\)\[\]{}]'), ' '); // Remove brackets/parentheses
    cleaned = cleaned.split(RegExp(r'[,\-–—]'))[0].trim(); // Take only first part before commas/dashes

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
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim(); // Normalize whitespace
    
    // If it's just a number, add "servings"
    if (RegExp(r'^\d+$').hasMatch(cleaned)) {
      final num = int.parse(cleaned);
      return '$num ${num == 1 ? 'serving' : 'servings'}';
    }

    // Last resort: return cleaned version if it's not empty
    return cleaned.isNotEmpty ? cleaned : servings;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
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
                      showRefreshButton: false,
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
                        if (widget.recipe.id.isNotEmpty) {
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

                        // 2) Always update the discover record so future fetches use the new URL
                        if (widget.recipe.id.isNotEmpty) {
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
                // Action buttons overlay (refresh removed)
                Positioned(
                  top: 8,
                  right: 6,
                  child: Row(
                    children: [
                      if (widget.showEditButton)
                        _buildActionButton(
                          icon: Icons.edit_note_rounded,
                          onTap: () async {
                            final result = await Navigator.pushNamed(
                              context,
                              '/recipeEdit',
                              arguments: widget.recipe.copyWith(toEdit: true),
                            );
                            if (result != null && result is Recipe) {
                              // Notify parent widget about the updated recipe
                              if (widget.onRecipeUpdated != null) {
                                widget.onRecipeUpdated!(result);
                              }
                            }
                          },
                          tooltip: 'Edit recipe',
                        ),
                      if (widget.showEditButton &&
                          (widget.showRemoveButton ||
                              widget.showSaveButton ||
                              widget.showShareButton))
                        SizedBox(width: AppSpacing.xs),

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
                          icon: Icons.save_rounded,
                          onTap: widget.onSave!,
                          tooltip: 'Save recipe',
                        ),
                      if (widget.showDeleteButton && widget.onDelete != null)
                        SizedBox(width: AppSpacing.xs),
                      if (widget.showDeleteButton && widget.onDelete != null)
                        _buildActionButton(
                          icon: Icons.delete_forever_rounded,
                          onTap: widget.onDelete!,
                          tooltip: 'Delete recipe (Dev only)',
                          iconColor: Colors.red,
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // Recipe details
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.responsive(
                  context,
                  mobile: 16,
                  tablet: 16,
                  desktop: 20,
                ),
                AppSpacing.responsive(
                  context,
                  mobile: 16,
                  tablet: 14,
                  desktop: 16,
                ),
                AppSpacing.responsive(
                  context,
                  mobile: 16,
                  tablet: 16,
                  desktop: 20,
                ),
                AppSpacing.responsive(
                  context,
                  mobile: 16,
                  tablet: 14,
                  desktop: 16,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.recipe.title,
                    style: TextStyle(
                      fontSize: AppTypography.responsiveHeadingSize(
                        context,
                        mobile: 16.0,
                        tablet: 19.0,
                        desktop: 22.0,
                      ),
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: AppBreakpoints.isMobile(context) ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  _buildRecipeInfo(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
