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
import '../providers/auth_provider.dart';
import '../theme/theme.dart';
import '../components/smart_recipe_image.dart';
import '../components/inline_banner_ad.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../services/image_replacement_service.dart';
import '../services/collection_service.dart';
import '../services/debug_settings.dart';
import '../models/recipe_collection.dart';
import '../utils/snackbar_helper.dart';
import '../utils/image_utils.dart';

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
  late Recipe _currentRecipe;
  Key _imageKey = UniqueKey();

  bool _checkIfSaved(RecipeProvider provider) {
    final userRecipes = provider.userRecipes;
    
    // Check by ID
    if (userRecipes.any((r) => r.id == widget.recipe.id)) return true;

    // Check by sourceUrl
    if (widget.recipe.sourceUrl != null &&
        widget.recipe.sourceUrl!.isNotEmpty) {
      if (userRecipes.any((r) => r.sourceUrl == widget.recipe.sourceUrl)) {
        return true;
      }
    }
    
    // Check title + description for fallback (matching Discover/Community recipes)
    final recipeKey =
        '${widget.recipe.title.toLowerCase()}|${widget.recipe.description.toLowerCase()}';
    final userRecipeKeys =
        userRecipes
            .map(
              (r) => '${r.title.toLowerCase()}|${r.description.toLowerCase()}',
            )
            .toSet();
    
    return userRecipeKeys.contains(recipeKey);
  }

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
      _imageKey = UniqueKey(); // Force SmartRecipeImage to rebuild completely
    });
    
    // Also update the recipe in the provider so other screens reflect the change
    final provider = context.read<RecipeProvider>();
    provider.updateRecipeImageLocally(_currentRecipe.id, newUrl);
    provider.emitRecipesChanged();
  }

  @override
  void initState() {
    super.initState();
    _currentRecipe = widget.recipe;
    _checkFavoriteStatus();
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
                      if (collection.name == 'Recently Added') {
                        return const SizedBox.shrink();
                      }
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
        // Navigate to collections screen to create new collection
        Navigator.pushNamed(context, '/collections');
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
        _currentRecipe,
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

  /// Build user attribution for community recipes
  /// Shows stacked profile photos and names of users who shared the recipe
  Widget _buildUserAttribution(Recipe recipe) {
    // Only show for community recipes (has sharedByDisplayName or sharedByUserId)
    final isCommunityRecipe =
        recipe.sharedByDisplayName != null || recipe.sharedByUserId != null;

    if (!isCommunityRecipe) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final users = recipe.sharedByUsers;
    final sharedByCount = recipe.sharedByCount;
    
    final iconSize = AppSizing.responsiveIconSize(
      context,
      mobile: 40,
      tablet: 44,
      desktop: 48,
    );
    final smallIconSize = AppSizing.responsiveIconSize(
      context,
      mobile: 24,
      tablet: 26,
      desktop: 28,
    );

    // Build stacked avatars (show up to 4 on detail screen)
    Widget buildStackedAvatars() {
      if (users.isEmpty) {
        // Fallback to single user
        return ClipOval(
          child: ImageUtils.buildProfileImage(
            imageUrl: recipe.sharedByPhotoUrl,
            width: iconSize,
            height: iconSize,
            fit: BoxFit.cover,
            errorWidget: _buildFallbackAvatar(theme, iconSize, smallIconSize),
          ),
        );
      }

      final displayUsers = users.take(4).toList();
      final overlapOffset = iconSize * 0.65;

      return SizedBox(
        width: iconSize + (overlapOffset * (displayUsers.length - 1).clamp(0, 3)),
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
                      color: theme.cardColor,
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: ImageUtils.buildProfileImage(
                      imageUrl: displayUsers[i].photoUrl,
                      width: iconSize - 4,
                      height: iconSize - 4,
                      fit: BoxFit.cover,
                      errorWidget: _buildFallbackAvatar(theme, iconSize - 4, smallIconSize - 4),
                    ),
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
        return recipe.sharedByDisplayName ?? 'Chef';
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
        return '${names.join(', ')} and $othersCount other${othersCount > 1 ? 's' : ''}';
      }
    }

    return Container(
      margin: EdgeInsets.only(top: AppSpacing.md),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Stacked profile photos
          buildStackedAvatars(),
          SizedBox(width: AppSpacing.md),
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sharedByCount > 1 ? 'Shared by' : 'Shared by',
                  style: TextStyle(
                    fontSize: AppTypography.responsiveFontSize(
                      context,
                      mobile: 11.0,
                      tablet: 12.0,
                      desktop: 13.0,
                    ),
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  buildAttributionText(),
                  style: TextStyle(
                    fontSize: AppTypography.responsiveFontSize(
                      context,
                      mobile: 14.0,
                      tablet: 15.0,
                      desktop: 16.0,
                    ),
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Community badge
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.people_rounded,
                  size: AppSizing.responsiveIconSize(
                    context,
                    mobile: 14,
                    tablet: 16,
                    desktop: 18,
                  ),
                  color: theme.colorScheme.primary,
                ),
                SizedBox(width: 4),
                Text(
                  'Community',
                  style: TextStyle(
                    fontSize: AppTypography.responsiveFontSize(
                      context,
                      mobile: 10.0,
                      tablet: 11.0,
                      desktop: 12.0,
                    ),
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build fallback avatar with person icon
  Widget _buildFallbackAvatar(ThemeData theme, double iconSize, double smallIconSize) {
    return Container(
      width: iconSize,
      height: iconSize,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person,
        size: smallIconSize,
        color: theme.colorScheme.primary,
      ),
    );
  }

  /// Build engagement stats for discoverable recipes
  /// Shows for:
  /// 1. User's own discoverable recipes (to see their recipe's engagement)
  /// 2. Community recipes from other users (when viewing from notification or community screen)
  Widget _buildEngagementStats(Recipe recipe) {
    final currentUser = context.read<AuthService>().user;

    // Check if this is the user's own recipe
    final isOwnRecipe = currentUser != null && recipe.userId == currentUser.uid;

    // Check if recipe has any engagement metrics
    final hasEngagement =
        recipe.likeCount > 0 || recipe.saveCount > 0 || recipe.shareCount > 0;

    // Check if this is a community recipe (has sharedByDisplayName or sharedByUserId)
    final isCommunityRecipe =
        recipe.sharedByDisplayName != null || recipe.sharedByUserId != null;

    // Show engagement stats if:
    // 1. It's the user's own recipe with engagement, OR
    // 2. It's a community recipe (from another user) with engagement
    if (!hasEngagement || (!isOwnRecipe && !isCommunityRecipe)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    // Different styling for own recipes vs community recipes
    final containerColor =
        isOwnRecipe
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final borderColor =
        isOwnRecipe
            ? theme.colorScheme.primary.withValues(alpha: 0.2)
            : theme.colorScheme.outline.withValues(alpha: 0.2);

    return Container(
      margin: EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        children: [
          // Show "Your Recipe Stats" label for own recipes
          if (isOwnRecipe) ...[
            Text(
              'Your Recipe Stats',
              style: TextStyle(
                fontSize: AppTypography.responsiveFontSize(
                  context,
                  mobile: 12.0,
                  tablet: 13.0,
                  desktop: 14.0,
                ),
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                icon: Icons.favorite_rounded,
                count: recipe.likeCount,
                label: 'likes',
                color: theme.colorScheme.error,
              ),
              _buildStatDivider(),
              _buildStatItem(
                icon: Icons.bookmark_rounded,
                count: recipe.saveCount,
                label: 'saves',
                color: theme.colorScheme.primary,
              ),
              _buildStatDivider(),
              _buildStatItem(
                icon: Icons.share_rounded,
                count: recipe.shareCount,
                label: 'shares',
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required int count,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: AppSizing.responsiveIconSize(
                context,
                mobile: 18,
                tablet: 20,
                desktop: 22,
              ),
              color: color,
            ),
            SizedBox(width: AppSpacing.xs),
            Text(
              '$count',
              style: TextStyle(
                fontSize: AppTypography.responsiveFontSize(
                  context,
                  mobile: 16.0,
                  tablet: 18.0,
                  desktop: 20.0,
                ),
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: AppTypography.responsiveFontSize(
              context,
              mobile: 11.0,
              tablet: 12.0,
              desktop: 13.0,
            ),
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
    );
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
          fullTitle: 'Recipe Details',
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
                final provider = context.read<RecipeProvider>();
                final isSaved = _checkIfSaved(provider);
                
                switch (action) {
                  case MenuAction.save:
                    if (isSaved) break;
                    final recipeProvider = provider;
                    
                    // Check if this is a discover/community recipe (different userId)
                    final currentUser = context.read<AuthService>().user;
                    final isDiscoverRecipe = currentUser != null && 
                        _currentRecipe.userId != currentUser.uid && 
                        _currentRecipe.id.isNotEmpty;
                    
                    // Pass originalRecipeId for save count tracking
                    final originalRecipeId = isDiscoverRecipe ? _currentRecipe.id : null;
                    
                    // Create a copy of the recipe with empty ID to ensure a new document is created
                    // This prevents overwriting the original discover recipe
                    final recipeToSave = _currentRecipe.copyWith(
                      id: '', // Clear ID to create new document
                      userId: currentUser?.uid, // Will be set by server, but clear locally
                    );
                    
                    final savedRecipe = await recipeProvider.createUserRecipe(
                      recipeToSave,
                      context,
                      originalRecipeId: originalRecipeId,
                    );
                    if (!context.mounted) break;
                    if (savedRecipe != null) {
                      // Update _currentRecipe to the saved version (with new ID)
                      setState(() {
                        _currentRecipe = savedRecipe;
                      });
                      
                      // Provider update will trigger rebuild and update isSaved status
                      SnackBarHelper.showSuccess(
                        context,
                        'Recipe saved successfully!',
                        action: SnackBarAction(
                          label: 'View Recipes',
                          textColor: Colors.white,
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
                      );
                    } else {
                      SnackBarHelper.showError(
                        context,
                        recipeProvider.error?.message ??
                            'Failed to save recipe',
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
                    // Show dialog to pick collection and add recipe immediately
                    _showAddToCollectionDialog();
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
                        SnackBarHelper.showSuccess(
                          context,
                          'Recipe deleted successfully!',
                        );
                      } else {
                        SnackBarHelper.showError(
                          context,
                          recipeProvider.error?.message ??
                              'Failed to delete recipe',
                        );
                      }
                    }
                    break;
                }
              },
              itemBuilder: (context) {
                final isSaved = _checkIfSaved(context.read<RecipeProvider>());
                final List<PopupMenuEntry<MenuAction>> items = [];
                // Only allow replacing image when the recipe is saved by the user
                // In production (release builds), this is strictly enforced
                // In debug builds, only allow if saved OR if not a discover recipe
                final bool canShowReplaceImage = isSaved;
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
                if (!isSaved) {
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
                if (isSaved) {
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
                  expandedHeight:
                      AppBreakpoints.isMobile(context)
                          ? 180
                          : AppBreakpoints.isTablet(context)
                          ? 300
                          : 400,
                  automaticallyImplyLeading: false,
                  flexibleSpace: FlexibleSpaceBar(
                    background: AspectRatio(
                      aspectRatio:
                          AppBreakpoints.isDesktop(context)
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
                              if (_checkIfSaved(
                                context.read<RecipeProvider>(),
                              )) {
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
                    padding: EdgeInsets.only(
                      left: AppSpacing.responsive(context),
                      right: AppSpacing.responsive(context),
                      top: AppSpacing.responsive(context),
                      bottom:
                          AppSpacing.responsive(context) +
                          60, // Extra space for floating bar
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

                        // User attribution for community recipes
                        _buildUserAttribution(recipe),

                        // Engagement stats for user's own discoverable recipes
                        _buildEngagementStats(recipe),

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
                        // Two-column layout for larger screens
                        AppBreakpoints.isTablet(context) ||
                                AppBreakpoints.isDesktop(context)
                            ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left column: Ingredients
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Ingredients',
                                        style: TextStyle(
                                          fontSize:
                                              AppTypography.responsiveHeadingSize(
                                                context,
                                                mobile: 18.0,
                                                tablet: 20.0,
                                                desktop: 22.0,
                                              ),
                                          fontWeight: FontWeight.bold,
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
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
                                                size:
                                                    AppSizing.responsiveIconSize(
                                                      context,
                                                      mobile: 6,
                                                      tablet: 8,
                                                      desktop: 8,
                                                    ),
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
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
                                    ],
                                  ),
                                ),
                                SizedBox(width: AppSpacing.xl),
                                // Right column: Instructions
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Instructions',
                                        style: TextStyle(
                                          fontSize:
                                              AppTypography.responsiveHeadingSize(
                                                context,
                                                mobile: 18.0,
                                                tablet: 20.0,
                                                desktop: 22.0,
                                              ),
                                          fontWeight: FontWeight.bold,
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                        ),
                                      ),
                                      SizedBox(height: AppSpacing.sm),
                                      ...recipe.instructions.asMap().entries.map(
                                        (entry) => Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: AppSpacing.sm,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                width:
                                                    AppSizing.responsiveIconSize(
                                                      context,
                                                      mobile: 24,
                                                      tablet: 28,
                                                      desktop: 32,
                                                    ),
                                                height:
                                                    AppSizing.responsiveIconSize(
                                                      context,
                                                      mobile: 24,
                                                      tablet: 28,
                                                      desktop: 32,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).colorScheme.primary,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    '${entry.key + 1}',
                                                    style: TextStyle(
                                                      color:
                                                          Theme.of(context)
                                                              .colorScheme
                                                              .onPrimary,
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                                    height: 1.5,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                            : // Single column layout for mobile
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ingredients',
                                  style: TextStyle(
                                    fontSize:
                                        AppTypography.responsiveHeadingSize(
                                          context,
                                          mobile: 18.0,
                                          tablet: 20.0,
                                          desktop: 22.0,
                                        ),
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
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
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
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
                                    fontSize:
                                        AppTypography.responsiveHeadingSize(
                                          context,
                                          mobile: 18.0,
                                          tablet: 20.0,
                                          desktop: 22.0,
                                        ),
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                SizedBox(height: AppSpacing.sm),
                                ...recipe.instructions.asMap().entries.map(
                                  (entry) => Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: AppSpacing.sm,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                                Theme.of(
                                                  context,
                                                ).colorScheme.primary,
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
                              ],
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
  // Check if this recipe belongs to the current user
  final currentUser = context.read<AuthService>().user;
  final isUserOwnedRecipe = currentUser != null && recipe.userId == currentUser.uid;
  
  // Check if this is a discover recipe (no userId or different userId)
  final isDiscover = !isUserOwnedRecipe && recipe.id.isNotEmpty;
  
  // Check if debug features are enabled (requires both debug mode AND setting enabled)
  final debugSettings = DebugSettings();
  final debugFeaturesEnabled = debugSettings.isDebugEnabled;
  
  // Gate discover - only allow replacing images on user-owned recipes
  // Unless debug features are explicitly enabled in settings
  if (isDiscover && !debugFeaturesEnabled) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Image replacement is not available for discover recipes. Save the recipe first.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  final theme = Theme.of(context);
  
  // Use stateful bottom sheet for better UX
  final result = await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    showDragHandle: true,
    backgroundColor: theme.colorScheme.surface,
    isScrollControlled: true, // Allow for dynamic height
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDialog.responsiveBorderRadius(context)),
      ),
    ),
    builder: (ctx) => _ImageReplaceSheetContent(recipe: recipe),
  );

  if (result == null) return;

  final candidateUrl = result['imageUrl'] as String?;
  final oldUrl = recipe.imageUrl;

  if (candidateUrl == null || !context.mounted) return;

  // Persist and refresh (using isUserOwnedRecipe from earlier in the function)
  final saved = await ImageReplacementService.persistRecipeImage(
    recipe: recipe,
    newImageUrl: candidateUrl,
    saveFn: (updated) async {
      try {
        if (isUserOwnedRecipe) {
          // User's own recipe - update via user endpoint
          final resp = await RecipeService.updateUserRecipe(updated);
          return resp.success ? resp.data : null;
        } else if (debugFeaturesEnabled && updated.id.isNotEmpty) {
          // Debug features enabled: allow updating discover items directly
          final resp = await RecipeService.updateDiscoverRecipeImage(
            recipeId: updated.id,
            imageUrl: candidateUrl,
          );
          return resp.success ? updated : null;
        }
      } catch (_) {}
      return updated; // Optimistic for transient contexts
    },
  );

  await ImageReplacementService.bustCaches(recipe, oldUrl: oldUrl);

  if (saved && context.mounted) {
    // Force UI to show new image immediately
    final state = context.findAncestorStateOfType<_RecipeDetailScreenState>();
    state?.applyImageReplacement(candidateUrl);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image replaced successfully.')),
    );
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not update image right now.')),
    );
  }
}

/// Stateful bottom sheet content for image replacement
/// Handles loading states, image selection, and preview all in one place
class _ImageReplaceSheetContent extends StatefulWidget {
  final Recipe recipe;
  
  const _ImageReplaceSheetContent({required this.recipe});
  
  @override
  State<_ImageReplaceSheetContent> createState() => _ImageReplaceSheetContentState();
}

class _ImageReplaceSheetContentState extends State<_ImageReplaceSheetContent> {
  bool _isLoading = false;
  List<String> _suggestedImages = [];
  String? _selectedImage;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
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
                // Show image suggestions if available
                if (_suggestedImages.isNotEmpty) ...[
                  _buildImageSelectionGrid(),
                  const SizedBox(height: 16),
                  _buildConfirmButton(),
                ] else if (_isLoading) ...[
                  _buildLoadingState(),
                ] else ...[
                  // Show main options
                  _buildOptionTile(
                    icon: Icons.photo_library_rounded,
                    title: 'Choose from device',
                    onTap: _pickFromDevice,
                  ),
                  _buildOptionTile(
                    icon: Icons.link_rounded,
                    title: 'Paste image URL',
                    onTap: _pasteUrl,
                      ),
                  _buildOptionTile(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Regenerate suggestion',
                    onTap: _regenerateSuggestion,
                  ),
                ],
                
                // Show error message if any
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                      style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 13,
                      ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
                    leading: Icon(
        icon,
                      size: AppSizing.responsiveIconSize(
                        context,
                        mobile: 24,
                        tablet: 28,
                        desktop: 32,
                      ),
                    ),
                    title: Text(
        title,
                      style: TextStyle(
                        fontSize: AppDialog.responsiveContentSize(context),
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
        horizontal: AppBreakpoints.isDesktop(context)
                              ? 20
            : AppBreakpoints.isTablet(context)
                              ? 18
                              : 16,
        vertical: AppBreakpoints.isDesktop(context)
                              ? 12
            : AppBreakpoints.isTablet(context)
                              ? 10
                              : 8,
                    ),
      onTap: onTap,
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Theme.of(context).colorScheme.primary,
                    ),
          ),
          const SizedBox(height: 16),
          Text(
            'Finding new images...',
                      style: TextStyle(
                        fontSize: AppDialog.responsiveContentSize(context),
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSelectionGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Select an image',
          style: TextStyle(
            fontSize: AppDialog.responsiveTitleSize(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _suggestedImages.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final imageUrl = _suggestedImages[index];
              final isSelected = _selectedImage == imageUrl;
              
              return GestureDetector(
                onTap: () => setState(() => _selectedImage = imageUrl),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
        ),
      );
    },
                          errorBuilder: (_, __, ___) => Container(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.broken_image_rounded,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check,
                                size: 16,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Retry button
        TextButton.icon(
          onPressed: _regenerateSuggestion,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Try different images'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _selectedImage != null
            ? () => Navigator.pop(context, {'imageUrl': _selectedImage})
            : null,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text('Use this image'),
      ),
    );
  }

  Future<void> _pickFromDevice() async {
    final imageUrl = await ImageReplacementService.pickFromDeviceAndUpload(
      widget.recipe,
      );
    if (imageUrl != null && mounted) {
      Navigator.pop(context, {'imageUrl': imageUrl});
    }
  }

  Future<void> _pasteUrl() async {
      final controller = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
      builder: (ctx) => AlertDialog(
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
    
    if (ok != true || !mounted) return;
    
        final url = controller.text.trim();
        if (await ImageReplacementService.validateImageUrl(url)) {
      if (mounted) Navigator.pop(context, {'imageUrl': url});
        } else {
      setState(() => _errorMessage = 'That link doesn\'t point to a valid image.');
          }
        }

  Future<void> _regenerateSuggestion() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _suggestedImages = [];
      _selectedImage = null;
    });

    try {
      // Use the optimized endpoint that returns multiple validated images
      final images = await ImageReplacementService.getMultipleSuggestions(
        widget.recipe.title,
        count: 4,
      );

      if (!mounted) return;

      if (images.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not find suitable images. Please try again.';
        });
      } else {
        setState(() {
          _isLoading = false;
          _suggestedImages = images;
          _selectedImage = images.first; // Pre-select first image
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'An error occurred. Please try again.';
        });
      }
    }
  }
}
