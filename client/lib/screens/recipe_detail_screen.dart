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
import '../components/floating_bottom_bar.dart';
import '../theme/theme.dart';
import '../components/smart_recipe_image.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  bool _isSaved = false;
  late Recipe _currentRecipe;

  @override
  void initState() {
    super.initState();
    _currentRecipe = widget.recipe;
    _checkFavoriteStatus();
    _checkSavedStatus();
  }

  /// Determines if the refresh button should be shown based on debug mode
  bool _shouldShowRefreshButton() {
    // Only show individual refresh buttons in debug mode
    // In production, users should use the bulk refresh in settings
    return kDebugMode;
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

  /// Determines if a recipe is custom (user-created or imported) vs external API
  bool _isCustomRecipe(Recipe recipe) {
    // Custom recipes are those that:
    // 1. Are AI-generated (user created with AI assistance)
    // 2. Have no external source (user created manually)
    // 3. Are imported from external sources (have source but are user-saved)
    return recipe.aiGenerated ||
        (recipe.source == null &&
            recipe.sourceUrl == null &&
            recipe.sourcePlatform == null);
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
          title: 'Recipe Details',
          floatingButtons: [
            // Show edit button only for custom recipes (user-created or imported)
            if (_isSaved && _isCustomRecipe(recipe))
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit Recipe',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => RecipeEditScreen(recipe: widget.recipe),
                    ),
                  );
                },
              ),
            // Show save button for unsaved recipes
            if (!_isSaved)
              IconButton(
                icon: const Icon(Icons.save),
                tooltip: 'Save Recipe',
                onPressed: () async {
                  final recipeProvider = context.read<RecipeProvider>();
                  final savedRecipe = await recipeProvider.createUserRecipe(
                    widget.recipe,
                    context,
                  );
                  if (context.mounted) {
                    if (savedRecipe != null) {
                      setState(() {
                        _isSaved = true;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Recipe saved successfully!'),
                          duration: Duration(seconds: 4),
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
                  }
                },
              ),
            // Show delete button for all saved recipes
            if (_isSaved)
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Delete Recipe',
                onPressed: () async {
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
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
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
                    if (context.mounted) {
                      if (success) {
                        setState(() {
                          _isSaved = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Recipe deleted successfully!'),
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
                  }
                },
              ),
          ],
        ),
        body: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: AppBreakpoints.isMobile(context) ? 180 : 220,
                  automaticallyImplyLeading: false,
                  flexibleSpace: FlexibleSpaceBar(
                    background: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: SmartRecipeImage(
                        recipeTitle: recipe.title,
                        primaryImageUrl: recipe.imageUrl,
                        fallbackStaticUrl: null,
                        fit: BoxFit.cover,
                        showRefreshButton: _shouldShowRefreshButton(),
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
                          if (recipe.id.isNotEmpty) {
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
                            context.read<RecipeProvider>().emitRecipesChanged();
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
            FloatingBottomBar(),
          ],
        ),
      ),
    );
  }
}
