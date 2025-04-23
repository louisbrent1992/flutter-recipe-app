import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/recipe.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final bool showRemoveButton;
  final bool showSaveButton;
  final VoidCallback? onSave;
  final double? aspectRatio;
  final bool showCookingTime;
  final bool showServings;

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
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe image
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: aspectRatio ?? 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: recipe.imageUrl,
                    fit: BoxFit.cover,
                    placeholder:
                        (context, url) =>
                            const Center(child: CircularProgressIndicator()),
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
                if (showRemoveButton && onRemove != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: InkWell(
                      onTap: onRemove,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                if (showSaveButton && onSave != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: InkWell(
                      onTap: onSave,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.save_outlined,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Recipe details
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (showCookingTime || showServings) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (showCookingTime) ...[
                          Icon(
                            Icons.timer_outlined,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          Text(
                            recipe.cookingTime,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                        if (showCookingTime && showServings) ...[
                          const SizedBox(width: 8),
                          Text('•', style: theme.textTheme.bodySmall),
                          const SizedBox(width: 8),
                        ],
                        if (showServings) ...[
                          Icon(
                            Icons.restaurant_outlined,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          Text(
                            '${recipe.servings} servings',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
