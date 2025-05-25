import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipease/components/html_description.dart';
import '../models/recipe.dart';
import '../components/custom_app_bar.dart';
import 'package:url_launcher/link.dart';
import '../providers/user_profile_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../components/floating_home_button.dart';
import '../components/floating_edit_button.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late Recipe _currentRecipe;

  @override
  void initState() {
    super.initState();
    _currentRecipe = widget.recipe;
    _checkFavoriteStatus();
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
                expandedHeight: 200,
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
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
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
                                _formatCookingTime(recipe.cookingTime),
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
                        'Description',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      HtmlDescription(
                        htmlContent: recipe.description,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),

                      _buildSourceLink(),
                      const SizedBox(height: 24),
                      Text(
                        'Ingredients',
                        style: Theme.of(context).textTheme.headlineMedium,
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
                        style: Theme.of(context).textTheme.headlineMedium,
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
                                          Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
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
                        Text(
                          'Tags',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
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
          const FloatingHomeButton(),
          FloatingEditButton(
            onPressed: () async {
              final result = await Navigator.pushNamed(
                context,
                '/recipeEdit',
                arguments: _currentRecipe.copyWith(toEdit: true),
              );
              if (result != null && result is Recipe) {
                setState(() {
                  _currentRecipe = result;
                });
              }
            },
          ),
        ],
      ),
    );
  }
}
