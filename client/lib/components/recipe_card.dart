import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:recipease/providers/recipe_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/recipe.dart';
import '../providers/user_profile_provider.dart';
import 'package:provider/provider.dart';

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
  final bool showFavoriteButton;
  final bool showShareButton;
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
    this.showFavoriteButton = true,
    this.showShareButton = true,
    this.onRecipeUpdated,
  });

  @override
  State<RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<RecipeCard> {
  bool _isFavoriteLoading = false;
  bool _isShareLoading = false;
  bool isFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
  }

  Future<void> _checkFavoriteStatus() async {
    final profile = context.read<UserProfileProvider>();
    final isFavoriteRecipe = await profile.isRecipeFavorite(widget.recipe);
    if (isFavoriteRecipe) {
      if (mounted) {
        setState(() {
          isFavorite = true;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          isFavorite = false;
        });
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isFavoriteLoading) return;

    final isCurrentlyFavorite = isFavorite;
    final confirm =
        isCurrentlyFavorite
            ? await showDialog<bool>(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Remove from Favorites'),
                    content: Text(
                      'Are you sure you want to remove "${widget.recipe.title}" from your favorites?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
            )
            : true;

    if (confirm != true) return;

    setState(() => _isFavoriteLoading = true);
    try {
      if (mounted) {
        final profile = context.read<UserProfileProvider>();

        if (isCurrentlyFavorite) {
          await profile.removeFromFavorites(widget.recipe);
          setState(() => isFavorite = false);
        } else {
          await profile.addToFavorites(widget.recipe);
          setState(() => isFavorite = true);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isCurrentlyFavorite
                    ? 'Removed "${widget.recipe.title}" from favorites'
                    : 'Added "${widget.recipe.title}" to favorites',
              ),
              backgroundColor: isCurrentlyFavorite ? Colors.orange : Colors.red,
              action:
                  isCurrentlyFavorite
                      ? SnackBarAction(
                        label: 'Undo',
                        onPressed: () async {
                          await profile.addToFavorites(widget.recipe);
                          setState(() => isFavorite = true);
                        },
                        textColor: Colors.white,
                      )
                      : SnackBarAction(
                        label: 'Go to favorites',
                        onPressed: () async {
                          Navigator.pushNamed(context, '/favorites');
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
            content: Text('Error updating favorites: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFavoriteLoading = false);
      }
    }
  }

  Future<void> _shareRecipe() async {
    if (_isShareLoading) return;

    setState(() => _isShareLoading = true);
    try {
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

      await Share.share(shareText);
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
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true && mounted) {
      final profile = context.read<RecipeProvider>();
      await profile.deleteUserRecipe(widget.recipe.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recipe "${widget.recipe.title}" deleted'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                await profile.saveGeneratedRecipe(widget.recipe);
              },
              textColor: Colors.white,
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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(153), // 0.6 alpha
            borderRadius: BorderRadius.circular(16),
          ),
          child:
              isLoading
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                  : Icon(
                    icon,
                    color: iconColor ?? Theme.of(context).colorScheme.primary,
                    size: 16,
                  ),
        ),
      ),
    );
  }

  Widget _buildRecipeInfo() {
    if (!widget.showCookingTime && !widget.showServings) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 16,
          alignment: WrapAlignment.spaceBetween,
          children: [
            if (widget.showCookingTime)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _formatCookingTime(widget.recipe.cookingTime),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            if (widget.showServings)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${widget.recipe.servings} servings',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.restaurant_outlined,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.recipe.difficulty,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatCookingTime(String cookingTime) {
    // If already contains 'hour' or 'minute', it's already formatted
    if (cookingTime.contains('hour') || cookingTime.contains('minute')) {
      return cookingTime;
    }

    // Try to parse as integer
    int? minutes = int.tryParse(cookingTime);
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
    if (RegExp(r'^\d+$').hasMatch(cookingTime)) {
      return '$cookingTime minutes';
    }

    // If we can't parse it, return as is
    return cookingTime;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    print(widget.recipe.imageUrl);

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
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
                  aspectRatio: widget.aspectRatio ?? 16 / 9,

                  child: Container(
                    padding: const EdgeInsets.all(4.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: widget.recipe.imageUrl,
                        fit: BoxFit.cover,

                        placeholder:
                            (context, url) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                        errorWidget:
                            (context, url, error) => Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.restaurant,
                                size: 48,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 6,
                  child: Row(
                    children: [
                      if (widget.showEditButton)
                        _buildActionButton(
                          icon: Icons.edit_outlined,
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
                              widget.showFavoriteButton ||
                              widget.showShareButton))
                        const SizedBox(width: 8),
                      if (widget.showFavoriteButton)
                        _buildActionButton(
                          icon:
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                          onTap: _toggleFavorite,
                          tooltip:
                              isFavorite
                                  ? 'Remove from favorites'
                                  : 'Add to favorites',
                          iconColor:
                              isFavorite
                                  ? Colors.red
                                  : Theme.of(context).colorScheme.primary,
                          isLoading: _isFavoriteLoading,
                        ),
                      if (widget.showFavoriteButton &&
                          (widget.showRemoveButton ||
                              widget.showSaveButton ||
                              widget.showShareButton))
                        const SizedBox(width: 8),
                      if (widget.showShareButton)
                        _buildActionButton(
                          icon: Icons.share_outlined,
                          onTap: _shareRecipe,
                          tooltip: 'Share recipe',
                          isLoading: _isShareLoading,
                        ),
                      if (widget.showShareButton &&
                          (widget.showRemoveButton || widget.showSaveButton))
                        const SizedBox(width: 8),
                      if (widget.showRemoveButton)
                        _buildActionButton(
                          icon: Icons.remove_circle_outline,
                          onTap: widget.onRemove ?? _deleteRecipe,
                          tooltip: 'Remove recipe',
                        ),
                      if (widget.showRemoveButton && widget.showSaveButton)
                        const SizedBox(width: 8),
                      if (widget.showSaveButton && widget.onSave != null)
                        _buildActionButton(
                          icon: Icons.save_outlined,
                          onTap: widget.onSave!,
                          tooltip: 'Save recipe',
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // Recipe details
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.recipe.title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
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
