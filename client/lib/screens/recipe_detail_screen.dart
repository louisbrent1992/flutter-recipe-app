import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/link.dart';
import '../models/recipe.dart';
import '../providers/user_profile_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe? recipe;

  const RecipeDetailScreen({super.key, this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
  }

  Future<void> _checkFavoriteStatus() async {
    if (widget.recipe == null) return;
    final profile = context.read<UserProfileProvider>();
    _isFavorite = await profile.isRecipeFavorite(widget.recipe!);
    if (mounted) setState(() {});
  }

  Future<void> _toggleFavorite() async {
    try {
      final profile = context.read<UserProfileProvider>();
      if (_isFavorite) {
        await profile.removeFromFavorites(widget.recipe!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed "${widget.recipe!.title}" from favorites'),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'Go to favorites',
                onPressed: () {
                  Navigator.pushNamed(context, '/favorites');
                },
                textColor: Colors.white,
              ),
            ),
          );
          setState(() => _isFavorite = false);
        }
      } else {
        await profile.addToFavorites(widget.recipe!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added "${widget.recipe!.title}" to favorites'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Go to favorites',
                onPressed: () {
                  Navigator.pushNamed(context, '/favorites');
                },
                textColor: Colors.white,
              ),
            ),
          );
          setState(() => _isFavorite = true);
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
    }
  }

  Future<void> _shareRecipe() async {
    if (widget.recipe == null) return;

    final recipe = widget.recipe!;

    // Determine source info to include
    String sourceInfo = '';
    if (recipe.source != null && recipe.source!.isNotEmpty) {
      sourceInfo = '\nSource: ${recipe.source}';
    } else if (recipe.instagram != null &&
        recipe.instagram!.shortcode != null) {
      sourceInfo =
          '\nOriginal Post: https://www.instagram.com/p/${recipe.instagram!.shortcode}/';
    }

    final String shareText = '''
${recipe.title}

Description:
${recipe.description}

Cooking Time: ${recipe.cookingTime}
Servings: ${recipe.servings}
Difficulty: ${recipe.difficulty}

Ingredients:
${recipe.ingredients.map((i) => '• $i').join('\n')}

Instructions:
${recipe.instructions.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}

${recipe.tags.isNotEmpty ? 'Tags: ${recipe.tags.join(', ')}' : ''}$sourceInfo

Shared from Recipe App
''';

    await Share.share(shareText);
  }

  Widget _buildSourceLink() {
    if (widget.recipe == null) return const SizedBox.shrink();

    final recipe = widget.recipe!;
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
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recipe.source != null) ...[
            Text(
              recipe.source!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
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
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      displayText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
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

  @override
  Widget build(BuildContext context) {
    if (widget.recipe == null) {
      return const Scaffold(body: Center(child: Text('Recipe not found')));
    }

    final recipe = widget.recipe!;

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: _shareRecipe),
          Consumer<UserProfileProvider>(
            builder: (context, profile, _) {
              return IconButton(
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.red : null,
                ),
                onPressed: _toggleFavorite,
              );
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    textAlign: TextAlign.center,
                    recipe.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.timer,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            recipe.cookingTime,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),

                      Row(
                        children: [
                          Icon(
                            Icons.people,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            recipe.servings,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),

                      Row(
                        children: [
                          Icon(
                            Icons.restaurant,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            recipe.difficulty,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    recipe.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  _buildSourceLink(),
                  const SizedBox(height: 24),
                  Text(
                    'Ingredients',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  ...recipe.ingredients.map(
                    (ingredient) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.circle, size: 8),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ingredient,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Instructions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  ...recipe.instructions.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${entry.key + 1}',
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (recipe.tags.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('Tags', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          recipe.tags
                              .map(
                                (tag) => Chip(
                                  label: Text(tag),
                                  backgroundColor:
                                      Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
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
    );
  }
}
