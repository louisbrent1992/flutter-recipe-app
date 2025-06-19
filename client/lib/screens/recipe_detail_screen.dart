import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipease/components/floating_button.dart';
import 'package:recipease/components/html_description.dart';
import 'package:recipease/providers/recipe_provider.dart';
import 'package:recipease/screens/favorite_recipes_screen.dart';
import 'package:recipease/screens/recipe_edit_screen.dart';
import '../models/recipe.dart';
import '../components/custom_app_bar.dart';
import 'package:url_launcher/link.dart';
import '../providers/user_profile_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../components/floating_bottom_bar.dart';
import '../theme/theme.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
    _checkSavedStatus();
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
    String? displayText;
    IconData? icon;

    if (recipe.instagram != null && recipe.instagram!.shortcode != null) {
      sourceUrl =
          recipe.sourceUrl ??
          'https://www.instagram.com/p/${recipe.instagram!.shortcode}/';
      displayText = 'View Post';
      icon = Icons.photo_camera;
    } else if (recipe.tiktok != null && recipe.tiktok!.videoId != null) {
      sourceUrl =
          recipe.sourceUrl ??
          'https://www.tiktok.com/@${recipe.tiktok!.username}/video/${recipe.tiktok!.videoId}';
      displayText = 'View Video';
      icon = Icons.video_library;
    } else if (recipe.youtube != null && recipe.youtube!.videoId != null) {
      sourceUrl =
          recipe.sourceUrl ??
          'https://www.youtube.com/watch?v=${recipe.youtube!.videoId}';
      displayText = 'Watch Video';
      icon = Icons.play_circle_outline;
    } else if (recipe.sourceUrl != null && recipe.sourceUrl!.isNotEmpty) {
      sourceUrl = recipe.sourceUrl;
      displayText = 'View Source';
      icon = Icons.link;
    }

    if (sourceUrl == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recipe.source != null) ...[
            Text(
              recipe.source!,
              style: TextStyle(
                fontSize: AppTypography.responsiveFontSize(context),
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
          ],
          Link(
            uri: Uri.parse(sourceUrl),
            target: LinkTarget.blank,
            builder: (BuildContext context, FollowLink? openLink) {
              return InkWell(
                onTap: openLink,
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
                    Text(
                      displayText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                        fontSize: AppTypography.responsiveFontSize(context),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
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
    if (widget.recipe.id.isEmpty) {
      return const Scaffold(body: Center(child: Text('Recipe not found')));
    }

    final recipe = widget.recipe;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Recipe Details'),
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
                    child: CachedNetworkImage(
                      imageUrl: recipe.imageUrl,
                      fit: BoxFit.cover,
                      placeholder:
                          (context, url) =>
                              const Center(child: CircularProgressIndicator()),
                      errorWidget:
                          (context, url, error) =>
                              const Icon(Icons.error, color: Colors.red),
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
                        textAlign: TextAlign.center,
                        recipe.title,
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
                                    fontSize: AppTypography.responsiveFontSize(
                                      context,
                                    ),
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
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
                                  color: Theme.of(context).colorScheme.primary,
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
                                    fontSize: AppTypography.responsiveFontSize(
                                      context,
                                    ),
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
                                    (tag) => Chip(
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
                                          ).colorScheme.surfaceContainerHighest,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm,
                                        vertical: AppSpacing.xs,
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
          if (_isSaved)
            FloatingButton(
              tooltip: 'Edit Recipe',
              icon: Icons.edit,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RecipeEditScreen(recipe: recipe),
                  ),
                );
              },
            )
          else
            FloatingButton(
              tooltip: 'Save Recipe',
              icon: Icons.save,
              onPressed: () async {
                final recipeProvider = context.read<RecipeProvider>();
                final savedRecipe = await recipeProvider.createUserRecipe(
                  recipe,
                  context,
                );
                if (context.mounted) {
                  if (savedRecipe != null) {
                    setState(() {
                      _isSaved = true;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Recipe saved successfully!'),
                        duration: Duration(seconds: 4),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          recipeProvider.error?.message ??
                              'Failed to save recipe',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          FloatingButton(
            position: 'left',
            tooltip: 'Favorite Recipes',
            icon: Icons.favorite,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FavoriteRecipesScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
