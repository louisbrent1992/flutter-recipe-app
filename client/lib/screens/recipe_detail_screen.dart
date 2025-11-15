import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../services/recipe_service.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:recipease/components/html_description.dart';
import 'package:recipease/providers/recipe_provider.dart';
import 'package:recipease/screens/recipe_edit_screen.dart';
import '../models/recipe.dart';
import '../components/custom_app_bar.dart';
import '../providers/user_profile_provider.dart';
import '../theme/theme.dart';
import '../components/smart_recipe_image.dart';
import '../components/inline_banner_ad.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../services/image_replacement_service.dart';

// Overflow menu actions for the recipe details screen
enum MenuAction {
  fixImage,
  save,
  addToCollection,
  share,
  copyIngredients,
  edit,
  delete,
}

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  bool _isSaved = false;
  late Recipe _currentRecipe;
  Key _imageKey = UniqueKey();

  String? _deriveSourceUrl(Recipe recipe) {
    if (recipe.sourceUrl != null && recipe.sourceUrl!.isNotEmpty) {
      return recipe.sourceUrl;
    }
    final instagram = recipe.instagram;
    final tiktok = recipe.tiktok;
    final youtube = recipe.youtube;
    if (instagram?.shortcode != null && instagram!.shortcode!.isNotEmpty) {
      return 'https://www.instagram.com/p/${instagram.shortcode!}/';
    }
    if (tiktok?.videoId != null &&
        tiktok!.videoId!.isNotEmpty &&
        (tiktok.username != null && tiktok.username!.isNotEmpty)) {
      return 'https://www.tiktok.com/@${tiktok.username!}/video/${tiktok.videoId!}';
    }
    if (youtube?.videoId != null && youtube!.videoId!.isNotEmpty) {
      return 'https://www.youtube.com/watch?v=${youtube.videoId!}';
    }
    if (recipe.source != null && recipe.source!.isNotEmpty) {
      final s = recipe.source!.trim();
      final looksLikeUrl =
          s.startsWith('http://') ||
          s.startsWith('https://') ||
          s.startsWith('www.');
      if (looksLikeUrl) {
        return s.startsWith('http') ? s : 'https://$s';
      }
    }
    return null;
  }

  String _buildShareText(Recipe recipe) {
    final buffer = StringBuffer();
    buffer.writeln(recipe.title);
    buffer.writeln('');
    // Meta
    final time = _formatCookingTime(recipe.cookingTime);
    final servings = recipe.servings;
    final difficulty = recipe.difficulty;
    buffer.writeln(
      'Time: $time  •  Servings: $servings  •  Difficulty: $difficulty',
    );
    buffer.writeln('');
    // Description
    if (recipe.description.trim().isNotEmpty) {
      buffer.writeln(recipe.description.trim());
      buffer.writeln('');
    }
    // Source
    final sourceUrl = _deriveSourceUrl(recipe);
    if (sourceUrl != null && sourceUrl.isNotEmpty) {
      buffer.writeln('Source: $sourceUrl');
      buffer.writeln('');
    }
    // Ingredients
    if (recipe.ingredients.isNotEmpty) {
      buffer.writeln('Ingredients:');
      for (final ing in recipe.ingredients) {
        buffer.writeln('• $ing');
      }
      buffer.writeln('');
    }
    // Instructions
    if (recipe.instructions.isNotEmpty) {
      buffer.writeln('Instructions:');
      for (int i = 0; i < recipe.instructions.length; i++) {
        final step = recipe.instructions[i];
        buffer.writeln('${i + 1}. $step');
      }
      buffer.writeln('');
    }
    buffer.writeln('Shared from RecipEase');
    return buffer.toString();
  }

  // Apply image replacement and trigger immediate UI refresh
  void applyImageReplacement(String newUrl) {
    setState(() {
      _currentRecipe = _currentRecipe.copyWith(imageUrl: newUrl);
      _imageKey = UniqueKey();
    });
  }

  @override
  void initState() {
    super.initState();
    _currentRecipe = widget.recipe;
    _checkFavoriteStatus();
    _checkSavedStatus();
  }

  // Image viewer
  void _openImageViewer(String imageUrl) {
    if (imageUrl.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.8),
        pageBuilder: (context, animation, secondary) {
          return Scaffold(
            backgroundColor: Colors.black.withValues(alpha: 0.9),
            body: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder:
                          (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white,
                            size: 48,
                          ),
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          );
        },
        transitionsBuilder: (context, animation, secondary, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  Widget _nutritionRow(BuildContext context, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: AppSizing.responsiveIconSize(
              context,
              mobile: 14,
              tablet: 16,
              desktop: 18,
            ),
            color: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: AppTypography.responsiveFontSize(context),
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: AppTypography.responsiveFontSize(context),
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNutritionValue(String label, String raw) {
    final value = raw.trim();
    final lower = value.toLowerCase();
    bool hasUnitSuffix(List<String> units) =>
        units.any((u) => lower.endsWith(u));

    String withUnit(String unit) {
      // If already has any alpha chars, assume a unit exists
      if (RegExp(r"[a-zA-Z]$").hasMatch(lower) || hasUnitSuffix([unit])) {
        return value;
      }
      return '$value $unit';
    }

    switch (label.toLowerCase()) {
      case 'protein':
      case 'carbs':
      case 'fat':
      case 'fiber':
      case 'sugar':
        return withUnit('g');
      case 'sodium':
        return withUnit('mg');
      case 'iron':
        // Display as % if no unit
        return hasUnitSuffix(['%']) ? value : '$value%';
      default:
        return value;
    }
  }

  Future<void> _checkFavoriteStatus() async {
    if (widget.recipe.id.isEmpty) return;
    context.read<UserProfileProvider>();
    if (mounted) setState(() {});
  }

  void _checkSavedStatus() {
    if (widget.recipe.id.isEmpty) return;
    final userRecipes = context.read<RecipeProvider>().userRecipes;
    setState(() {
      _isSaved = userRecipes.any((recipe) => recipe.id == widget.recipe.id);
    });
  }

  Widget _buildSourceLink() {
    if (widget.recipe.id.isEmpty) return const SizedBox.shrink();

    final recipe = widget.recipe;
    String? sourceUrl;
    String? platformLabel;
    String? detailsLabel;
    IconData icon = Icons.link;

    // Prefer explicit sourceUrl if present
    if ((recipe.sourceUrl != null && recipe.sourceUrl!.isNotEmpty)) {
      sourceUrl = recipe.sourceUrl;
    }

    // If no explicit URL, try to build from social IDs
    if (sourceUrl == null || sourceUrl.isEmpty) {
      final instagram = recipe.instagram;
      final tiktok = recipe.tiktok;
      final youtube = recipe.youtube;

      if (instagram?.shortcode != null && instagram!.shortcode!.isNotEmpty) {
        sourceUrl = 'https://www.instagram.com/p/${instagram.shortcode!}/';
      } else if (tiktok?.videoId != null &&
          tiktok!.videoId!.isNotEmpty &&
          (tiktok.username != null && tiktok.username!.isNotEmpty)) {
        sourceUrl =
            'https://www.tiktok.com/@${tiktok.username!}/video/${tiktok.videoId!}';
      } else if (youtube?.videoId != null && youtube!.videoId!.isNotEmpty) {
        sourceUrl = 'https://www.youtube.com/watch?v=${youtube.videoId!}';
      }
    }

    // If still no URL, see if recipe.source looks like a URL
    if ((sourceUrl == null || sourceUrl.isEmpty) &&
        recipe.source != null &&
        recipe.source!.isNotEmpty) {
      final s = recipe.source!.trim();
      final looksLikeUrl =
          s.startsWith('http://') ||
          s.startsWith('https://') ||
          s.startsWith('www.');
      if (looksLikeUrl) {
        sourceUrl = s.startsWith('http') ? s : 'https://$s';
      }
    }

    // Determine platform/details labels
    final lower = (sourceUrl ?? '').toLowerCase();
    if (lower.contains('instagram.com')) {
      icon = Icons.photo_camera;
      platformLabel = 'Instagram';
      detailsLabel =
          recipe.instagram?.username != null &&
                  recipe.instagram!.username!.isNotEmpty
              ? '@${recipe.instagram!.username!}'
              : 'Post';
    } else if (lower.contains('tiktok.com')) {
      icon = Icons.video_library;
      platformLabel = 'TikTok';
      detailsLabel =
          recipe.tiktok?.username != null && recipe.tiktok!.username!.isNotEmpty
              ? '@${recipe.tiktok!.username!}'
              : 'Video';
    } else if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      icon = Icons.play_circle_outline;
      platformLabel = 'YouTube';
      detailsLabel =
          recipe.youtube?.channelTitle != null &&
                  recipe.youtube!.channelTitle!.isNotEmpty
              ? recipe.youtube!.channelTitle!
              : 'Video';
    } else if (sourceUrl != null && sourceUrl.isNotEmpty) {
      // Derive host from URL
      try {
        final uri = Uri.parse(sourceUrl);
        var host = uri.host;
        if (host.startsWith('www.')) host = host.substring(4);
        platformLabel = host;
      } catch (_) {
        platformLabel = recipe.source?.trim();
      }
    } else if (recipe.sourcePlatform != null &&
        recipe.sourcePlatform!.isNotEmpty) {
      platformLabel = recipe.sourcePlatform!.trim();
    } else if (recipe.source != null && recipe.source!.isNotEmpty) {
      platformLabel = recipe.source!.trim();
    }

    // Fallback for generated recipes without any source
    if ((platformLabel == null || platformLabel.isEmpty) &&
        recipe.aiGenerated == true) {
      icon = Icons.auto_awesome;
      platformLabel = 'User Generated';
      detailsLabel = null;
    }

    // If still no platform to show, render nothing
    if (platformLabel == null || platformLabel.isEmpty) {
      return const SizedBox.shrink();
    }

    // If no URL to launch, render as non-clickable
    if (sourceUrl == null || sourceUrl.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(
              icon,
              size: AppSizing.responsiveIconSize(
                context,
                mobile: 18,
                tablet: 20,
                desktop: 22,
              ),
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                detailsLabel != null && detailsLabel.isNotEmpty
                    ? '$platformLabel · $detailsLabel'
                    : platformLabel,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: AppTypography.responsiveFontSize(context),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Render clickable row with URL launching functionality
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: GestureDetector(
        onTap: () => _launchUrl(sourceUrl!),
        child: Row(
          children: [
            Icon(
              icon,
              size: AppSizing.responsiveIconSize(
                context,
                mobile: 18,
                tablet: 20,
                desktop: 22,
              ),
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                detailsLabel != null && detailsLabel.isNotEmpty
                    ? '$platformLabel · $detailsLabel'
                    : platformLabel,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: AppTypography.responsiveFontSize(context),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open $url'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        );
      }
    }
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
    if (widget.recipe.id.isEmpty) {
      return const Scaffold(body: Center(child: Text('Recipe not found')));
    }

    final recipe = _currentRecipe;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pop(context, _currentRecipe);
        }
      },
      child: Scaffold(
        appBar: CustomAppBar(
          title: 'Details',
          floatingButtons: [
            // Overflow menu (Edit/Delete)
            PopupMenuButton<MenuAction>(
              tooltip: 'More',
              icon: const Icon(Icons.more_vert),
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
              onSelected: (action) async {
                switch (action) {
                  case MenuAction.save:
                    if (_isSaved) break;
                    final recipeProvider = context.read<RecipeProvider>();
                    final savedRecipe = await recipeProvider.createUserRecipe(
                      widget.recipe,
                      context,
                    );
                    if (!context.mounted) break;
                    if (savedRecipe != null) {
                      setState(() {
                        _isSaved = true;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Recipe saved successfully!'),
                          duration: const Duration(seconds: 4),
                          action: SnackBarAction(
                            label: 'View Recipes',
                            onPressed: () {
                              if (mounted) {
                                Navigator.pushNamed(
                                  context,
                                  '/myRecipes',
                                  arguments: savedRecipe,
                                );
                              }
                            },
                          ),
                          backgroundColor:
                              Theme.of(context).colorScheme.success,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            recipeProvider.error?.message ??
                                'Failed to save recipe',
                          ),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                      );
                    }
                    break;
                  case MenuAction.edit:
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => RecipeEditScreen(
                              recipe: _currentRecipe.copyWith(toEdit: true),
                            ),
                      ),
                    );
                    break;
                  case MenuAction.fixImage:
                    await _showReplaceImageSheet(context, recipe);
                    break;
                  case MenuAction.addToCollection:
                    // Navigate to collections screen where user can add recipe
                    Navigator.pushNamed(context, '/collections');
                    break;
                  case MenuAction.share:
                    try {
                      // Longer delay to ensure any previous platform views (ads) are fully dismissed
                      await Future.delayed(const Duration(milliseconds: 300));
                      final shareText = _buildShareText(recipe);
                      // iPad requires a source rect; provide a safe fallback
                      if (context.mounted) {
                        final renderBox =
                            context.findRenderObject() as RenderBox?;

                        final origin =
                            renderBox != null
                                ? renderBox.localToGlobal(Offset.zero) &
                                    renderBox.size
                                : const Rect.fromLTWH(0, 0, 1, 1);
                        await Share.share(
                          shareText,
                          subject: recipe.title,
                          sharePositionOrigin: origin,
                        );
                      }
                    } catch (e) {
                      // Handle platform view conflicts gracefully
                      // Fallback to copying the full recipe text
                      final shareText = _buildShareText(recipe);
                      try {
                        await Clipboard.setData(ClipboardData(text: shareText));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Share sheet unavailable. Recipe copied to clipboard.',
                              ),
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(10),
                                ),
                              ),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      } catch (clipboardError) {
                        // If clipboard also fails, show error message
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Unable to open share sheet. Please try again.',
                              ),
                              backgroundColor:
                                  Theme.of(context).colorScheme.error,
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(10),
                                ),
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    }
                    break;
                  case MenuAction.copyIngredients:
                    final text = recipe.ingredients.join('\n');
                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Ingredients copied'),
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                    break;
                  case MenuAction.delete:
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Delete Recipe'),
                            content: const Text(
                              'Are you sure you want to delete this recipe?',
                            ),
                            actions: [
                              TextButton(
                                onPressed:
                                    () => Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed:
                                    () => Navigator.of(context).pop(true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                    );
                    if (confirmed == true && context.mounted) {
                      final recipeProvider = context.read<RecipeProvider>();
                      final success = await recipeProvider.deleteUserRecipe(
                        widget.recipe.id,
                        context,
                      );
                      if (!context.mounted) break;
                      if (success) {
                        setState(() {
                          _isSaved = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Recipe deleted successfully!'),
                            backgroundColor:
                                Theme.of(context).colorScheme.success,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              recipeProvider.error?.message ??
                                  'Failed to delete recipe',
                            ),
                            backgroundColor:
                                Theme.of(context).colorScheme.error,
                          ),
                        );
                      }
                    }
                    break;
                }
              },
              itemBuilder: (context) {
                final List<PopupMenuEntry<MenuAction>> items = [];
                // Only allow replacing image when the recipe is saved by the user
                // In production (release builds), this is strictly enforced
                // In debug builds, only allow if saved OR if not a discover recipe
                final bool canShowReplaceImage = _isSaved;
                if (canShowReplaceImage) {
                  items.add(
                    PopupMenuItem<MenuAction>(
                      value: MenuAction.fixImage,
                      child: Row(
                        children: [
                          Icon(
                            Icons.image,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text('Replace image'),
                        ],
                      ),
                    ),
                  );
                }
                if (!_isSaved) {
                  items.add(
                    PopupMenuItem<MenuAction>(
                      value: MenuAction.save,
                      child: Row(
                        children: [
                          Icon(
                            Icons.bookmark_add,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text('Save recipe'),
                        ],
                      ),
                    ),
                  );
                } else {
                  items.addAll([
                    PopupMenuItem<MenuAction>(
                      value: MenuAction.addToCollection,
                      child: Row(
                        children: [
                          Icon(
                            Icons.playlist_add,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text('Add to collection'),
                        ],
                      ),
                    ),
                  ]);
                }
                items.addAll([
                  PopupMenuItem<MenuAction>(
                    value: MenuAction.share,
                    child: Row(
                      children: [
                        Icon(
                          Icons.ios_share,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text('Share Recipe'),
                      ],
                    ),
                  ),
                  PopupMenuItem<MenuAction>(
                    value: MenuAction.copyIngredients,
                    child: Row(
                      children: [
                        Icon(
                          Icons.content_copy,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text('Copy ingredients'),
                      ],
                    ),
                  ),
                ]);
                if (_isSaved) {
                  items.add(
                    PopupMenuItem<MenuAction>(
                      value: MenuAction.edit,
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text('Edit Recipe'),
                        ],
                      ),
                    ),
                  );
                  items.add(
                    PopupMenuItem<MenuAction>(
                      value: MenuAction.delete,
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete,
                            size: 18,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          const Text('Delete Recipe'),
                        ],
                      ),
                    ),
                  );
                }
                return items;
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: AppBreakpoints.isMobile(context)
                      ? 180
                      : AppBreakpoints.isTablet(context)
                          ? 300
                          : 400,
                  automaticallyImplyLeading: false,
                  flexibleSpace: FlexibleSpaceBar(
                    background: AspectRatio(
                      aspectRatio: AppBreakpoints.isDesktop(context)
                          ? 21 / 9
                          : AppBreakpoints.isTablet(context)
                              ? 18 / 9
                              : 16 / 9,
                      child: Stack(
                        children: [
                          SmartRecipeImage(
                            key: _imageKey,
                            recipeTitle: recipe.title,
                            primaryImageUrl: recipe.imageUrl,
                            fallbackStaticUrl: null,
                            fit: BoxFit.cover,
                            // Disable inline lookup to avoid accidental changes; available via menu
                            showRefreshButton: false,
                            onResolvedUrl: (url) async {
                              if (url.isEmpty || url == recipe.imageUrl) return;
                              final updated = recipe.copyWith(imageUrl: url);
                              // Avoid surfacing provider-wide errors (e.g., 403)
                              // Only attempt a silent server update if this recipe is saved
                              if (_isSaved) {
                                try {
                                  await RecipeService.updateUserRecipe(updated);
                                } catch (_) {
                                  // Ignore failures to prevent global error overlay
                                }
                              }
                              // Only allow discover DB image updates during debug sessions
                              if (kDebugMode && recipe.id.isNotEmpty) {
                                try {
                                  await RecipeService.updateDiscoverRecipeImage(
                                    recipeId: recipe.id,
                                    imageUrl: url,
                                  );
                                } catch (_) {
                                  // Ignore failures
                                }
                              }
                              if (context.mounted) {
                                setState(() {
                                  _currentRecipe = updated;
                                });
                                // Emit cross-screen refresh after image update
                                context
                                    .read<RecipeProvider>()
                                    .emitRecipesChanged();
                              }
                            },
                            cacheKey:
                                recipe.id.isNotEmpty
                                    ? 'discover-${recipe.id}'
                                    : 'discover-${recipe.title.toLowerCase()}-${recipe.description.toLowerCase()}',
                            placeholder: const Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: Icon(
                              Icons.error,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Material(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                onTap: () => _openImageViewer(recipe.imageUrl),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.open_in_full_rounded,
                                    size: AppSizing.responsiveIconSize(
                                      context,
                                      mobile: 16,
                                      tablet: 18,
                                      desktop: 20,
                                    ),
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.responsive(context),
                      AppSpacing.responsive(context),
                      AppSpacing.responsive(context),
                      60,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Inline banner ad for free users
                        const InlineBannerAd(),

                        SizedBox(height: AppSpacing.lg),
                        Text(
                          recipe.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: AppTypography.responsiveHeadingSize(
                              context,
                              mobile: 22.0,
                              tablet: 26.0,
                              desktop: 30.0,
                            ),
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.responsive(context),

                          runSpacing: AppSpacing.xs,

                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer,
                                  size: AppSizing.responsiveIconSize(
                                    context,
                                    mobile: 16,
                                    tablet: 18,
                                    desktop: 20,
                                  ),
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                SizedBox(width: AppSpacing.xs),
                                Text(
                                  _formatCookingTime(recipe.cookingTime),
                                  style: TextStyle(
                                    fontSize: AppTypography.responsiveFontSize(
                                      context,
                                    ),
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),

                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.people,
                                  size: AppSizing.responsiveIconSize(
                                    context,
                                    mobile: 16,
                                    tablet: 18,
                                    desktop: 20,
                                  ),
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                SizedBox(width: AppSpacing.xs),
                                Text(
                                  recipe.servings,
                                  style: TextStyle(
                                    fontSize: AppTypography.responsiveFontSize(
                                      context,
                                    ),
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),

                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.restaurant,
                                  size: AppSizing.responsiveIconSize(
                                    context,
                                    mobile: 16,
                                    tablet: 18,
                                    desktop: 20,
                                  ),
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                SizedBox(width: AppSpacing.xs),
                                Text(
                                  recipe.difficulty,
                                  style: TextStyle(
                                    fontSize: AppTypography.responsiveFontSize(
                                      context,
                                    ),
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        SizedBox(height: AppSpacing.lg),

                        Text(
                          'Description',
                          style: TextStyle(
                            fontSize: AppTypography.responsiveHeadingSize(
                              context,
                              mobile: 18.0,
                              tablet: 20.0,
                              desktop: 22.0,
                            ),
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(height: AppSpacing.sm),
                        HtmlDescription(
                          htmlContent: recipe.description,
                          style: TextStyle(
                            fontSize: AppTypography.responsiveFontSize(context),
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.5,
                          ),
                        ),

                        _buildSourceLink(),
                        SizedBox(height: AppSpacing.xl),
                        Text(
                          'Ingredients',
                          style: TextStyle(
                            fontSize: AppTypography.responsiveHeadingSize(
                              context,
                              mobile: 18.0,
                              tablet: 20.0,
                              desktop: 22.0,
                            ),
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(height: AppSpacing.sm),
                        ...recipe.ingredients.map(
                          (ingredient) => Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.xs,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: AppSizing.responsiveIconSize(
                                    context,
                                    mobile: 6,
                                    tablet: 8,
                                    desktop: 8,
                                  ),
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    ingredient,
                                    style: TextStyle(
                                      fontSize:
                                          AppTypography.responsiveFontSize(
                                            context,
                                          ),
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: AppSpacing.xl),
                        Text(
                          'Instructions',
                          style: TextStyle(
                            fontSize: AppTypography.responsiveHeadingSize(
                              context,
                              mobile: 18.0,
                              tablet: 20.0,
                              desktop: 22.0,
                            ),
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(height: AppSpacing.sm),
                        ...recipe.instructions.asMap().entries.map(
                          (entry) => Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: AppSizing.responsiveIconSize(
                                    context,
                                    mobile: 24,
                                    tablet: 28,
                                    desktop: 32,
                                  ),
                                  height: AppSizing.responsiveIconSize(
                                    context,
                                    mobile: 24,
                                    tablet: 28,
                                    desktop: 32,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${entry.key + 1}',
                                      style: TextStyle(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize:
                                            AppTypography.responsiveFontSize(
                                              context,
                                              mobile: 12.0,
                                              tablet: 14.0,
                                              desktop: 16.0,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Text(
                                    entry.value,
                                    style: TextStyle(
                                      fontSize:
                                          AppTypography.responsiveFontSize(
                                            context,
                                          ),
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (recipe.nutrition != null) ...[
                          SizedBox(height: AppSpacing.xl),
                          Text(
                            'Nutrition Facts (approx.)',
                            style: TextStyle(
                              fontSize: AppTypography.responsiveHeadingSize(
                                context,
                                mobile: 18.0,
                                tablet: 20.0,
                                desktop: 22.0,
                              ),
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(height: AppSpacing.sm),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (recipe.nutrition!.calories != null)
                                _nutritionRow(
                                  context,
                                  'Calories',
                                  '${recipe.nutrition!.calories} kcal',
                                ),
                              if (recipe.nutrition!.protein != null)
                                _nutritionRow(
                                  context,
                                  'Protein',
                                  _formatNutritionValue(
                                    'Protein',
                                    recipe.nutrition!.protein!,
                                  ),
                                ),
                              if (recipe.nutrition!.carbs != null)
                                _nutritionRow(
                                  context,
                                  'Carbs',
                                  _formatNutritionValue(
                                    'Carbs',
                                    recipe.nutrition!.carbs!,
                                  ),
                                ),
                              if (recipe.nutrition!.fat != null)
                                _nutritionRow(
                                  context,
                                  'Fat',
                                  _formatNutritionValue(
                                    'Fat',
                                    recipe.nutrition!.fat!,
                                  ),
                                ),
                              if (recipe.nutrition!.fiber != null)
                                _nutritionRow(
                                  context,
                                  'Fiber',
                                  _formatNutritionValue(
                                    'Fiber',
                                    recipe.nutrition!.fiber!,
                                  ),
                                ),
                              if (recipe.nutrition!.sugar != null)
                                _nutritionRow(
                                  context,
                                  'Sugar',
                                  _formatNutritionValue(
                                    'Sugar',
                                    recipe.nutrition!.sugar!,
                                  ),
                                ),
                              if (recipe.nutrition!.sodium != null)
                                _nutritionRow(
                                  context,
                                  'Sodium',
                                  _formatNutritionValue(
                                    'Sodium',
                                    recipe.nutrition!.sodium!,
                                  ),
                                ),
                              if (recipe.nutrition!.iron != null)
                                _nutritionRow(
                                  context,
                                  'Iron',
                                  _formatNutritionValue(
                                    'Iron',
                                    recipe.nutrition!.iron!,
                                  ),
                                ),
                            ],
                          ),
                        ],

                        if (recipe.tags.isNotEmpty) ...[
                          SizedBox(height: AppSpacing.xl),
                          Text(
                            'Tags',
                            style: TextStyle(
                              fontSize: AppTypography.responsiveHeadingSize(
                                context,
                                mobile: 18.0,
                                tablet: 20.0,
                                desktop: 22.0,
                              ),
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children:
                                recipe.tags
                                    .map(
                                      (tag) => InkWell(
                                        onTap: () {
                                          Navigator.pushNamed(
                                            context,
                                            '/discover',
                                            arguments: {'tag': tag},
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(16),
                                        child: Chip(
                                          label: Text(
                                            tag,
                                            style: TextStyle(
                                              fontSize:
                                                  AppTypography.responsiveFontSize(
                                                    context,
                                                    mobile: 12.0,
                                                    tablet: 14.0,
                                                    desktop: 16.0,
                                                  ),
                                            ),
                                          ),
                                          backgroundColor:
                                              Theme.of(
                                                context,
                                              ).colorScheme.surface,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: AppSpacing.sm,
                                            vertical: AppSpacing.xs,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showReplaceImageSheet(BuildContext context, Recipe recipe) async {
  final isDiscover = recipe.id.isNotEmpty && (recipe.sourceUrl == null);
  // Gate discover in release
  if (isDiscover && !kDebugMode) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Image replacement is not available for discover recipes.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  final theme = Theme.of(context);
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    backgroundColor: theme.colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(
          AppDialog.responsiveBorderRadius(context),
        ),
      ),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: AppDialog.responsiveMaxWidth(context),
            ),
            child: Padding(
              padding: AppDialog.responsivePadding(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.photo_library_rounded,
                      size: AppSizing.responsiveIconSize(
                        context,
                        mobile: 24,
                        tablet: 28,
                        desktop: 32,
                      ),
                    ),
                    title: Text(
                      'Choose from device',
                      style: TextStyle(
                        fontSize: AppDialog.responsiveContentSize(context),
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppBreakpoints.isDesktop(ctx)
                          ? 20
                          : AppBreakpoints.isTablet(ctx)
                              ? 18
                              : 16,
                      vertical: AppBreakpoints.isDesktop(ctx)
                          ? 12
                          : AppBreakpoints.isTablet(ctx)
                              ? 10
                              : 8,
                    ),
                    onTap: () => Navigator.pop(ctx, 'device'),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.link_rounded,
                      size: AppSizing.responsiveIconSize(
                        context,
                        mobile: 24,
                        tablet: 28,
                        desktop: 32,
                      ),
                    ),
                    title: Text(
                      'Paste image URL',
                      style: TextStyle(
                        fontSize: AppDialog.responsiveContentSize(context),
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppBreakpoints.isDesktop(ctx)
                          ? 20
                          : AppBreakpoints.isTablet(ctx)
                              ? 18
                              : 16,
                      vertical: AppBreakpoints.isDesktop(ctx)
                          ? 12
                          : AppBreakpoints.isTablet(ctx)
                              ? 10
                              : 8,
                    ),
                    onTap: () => Navigator.pop(ctx, 'url'),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.auto_awesome_rounded,
                      size: AppSizing.responsiveIconSize(
                        context,
                        mobile: 24,
                        tablet: 28,
                        desktop: 32,
                      ),
                    ),
                    title: Text(
                      'Regenerate suggestion',
                      style: TextStyle(
                        fontSize: AppDialog.responsiveContentSize(context),
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppBreakpoints.isDesktop(ctx)
                          ? 20
                          : AppBreakpoints.isTablet(ctx)
                              ? 18
                              : 16,
                      vertical: AppBreakpoints.isDesktop(ctx)
                          ? 12
                          : AppBreakpoints.isTablet(ctx)
                              ? 10
                              : 8,
                    ),
                    onTap: () => Navigator.pop(ctx, 'regen'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  if (choice == null) return;

  String? candidateUrl;
  String? oldUrl = recipe.imageUrl;

  if (context.mounted) {
    if (choice == 'device') {
      candidateUrl = await ImageReplacementService.pickFromDeviceAndUpload(
        recipe,
      );
    } else if (choice == 'url') {
      final controller = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Paste image URL'),
              content: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'https://example.com/image.jpg',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Validate'),
                ),
              ],
            ),
      );
      if (ok == true) {
        final url = controller.text.trim();
        if (await ImageReplacementService.validateImageUrl(url)) {
          candidateUrl = url;
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('That link doesn\'t point to a valid image.'),
              ),
            );
          }
        }
      }
    } else if (choice == 'regen') {
      candidateUrl = await ImageReplacementService.searchSuggestion(
        recipe.title,
        starts: const [4, 7, 10, 13, 16],
      );
    }
  }
  if (candidateUrl == null) return;
  if (context.mounted) {
    // Preview dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Replace image?'),
            content: SizedBox(
              width: 300,
              child: Image.network(candidateUrl!, fit: BoxFit.contain),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Replace'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    // Persist and refresh
    final saved = await ImageReplacementService.persistRecipeImage(
      recipe: recipe,
      newImageUrl: candidateUrl,
      saveFn: (updated) async {
        try {
          // Debug: allow updating discover items directly
          if (kDebugMode && updated.id.isNotEmpty) {
            final resp = await RecipeService.updateDiscoverRecipeImage(
              recipeId: updated.id,
              imageUrl: candidateUrl!,
            );
            return resp.success ? updated : null;
          }
          // Production: only user-saved recipes via user endpoint
          final resp = await RecipeService.updateUserRecipe(updated);
          return resp.success ? resp.data : null;
        } catch (_) {}
        return updated; // Optimistic for transient contexts
      },
    );

    await ImageReplacementService.bustCaches(recipe, oldUrl: oldUrl);

    if (saved && context.mounted) {
      // Force UI to show new image immediately
      if (context.mounted) {
        final state =
            context.findAncestorStateOfType<_RecipeDetailScreenState>();
        state?.applyImageReplacement(candidateUrl);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image replaced successfully.')),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update image right now.')),
      );
    }
  }
}
