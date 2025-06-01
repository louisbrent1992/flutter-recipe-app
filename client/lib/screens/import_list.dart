import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../theme/theme.dart';

class ImportListScreen extends StatefulWidget {
  const ImportListScreen({super.key});

  @override
  State<ImportListScreen> createState() => _ImportListScreenState();
}

class _ImportListScreenState extends State<ImportListScreen> {
  final ScrollController _scrollController = ScrollController();

  // Sample recipes for demonstration
  final List<Recipe> _recipes = [
    Recipe(
      id: '1',
      title: 'Spaghetti Carbonara',
      description:
          'Classic Italian pasta dish with eggs, cheese, pancetta and black pepper',
      source: 'Instagram',
      sourcePlatform: 'Instagram',
      imageUrl:
          'https://plus.unsplash.com/premium_photo-1691948106030-d5e76d461b14?w=900&auto=format&fit=crop&q=60&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MXx8c3BhZ2hldHRpJTIwY2FyYm9uYXJhfGVufDB8fDB8fHww',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ingredients: ['Pasta', 'Eggs', 'Cheese', 'Pancetta', 'Black Pepper'],
    ),
    Recipe(
      id: '2',
      title: 'Fresh Garden Salad',
      description: 'Light and refreshing salad with seasonal vegetables',
      source: 'YouTube',
      sourcePlatform: 'YouTube',
      imageUrl:
          'https://images.unsplash.com/photo-1574031491550-35f444917508?w=900&auto=format&fit=crop&q=60&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxzZWFyY2h8N3x8ZnJlc2glMjBnYXJkZW4lMjBzYWxhZHxlbnwwfHwwfHx8MA%3D%3D',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ingredients: ['Lettuce', 'Tomato', 'Cucumber', 'Bell Pepper', 'Dressing'],
    ),
    Recipe(
      id: '3',
      title: 'Chocolate Cake',
      description:
          'Rich and decadent chocolate cake perfect for special occasions',
      source: 'Website',
      sourcePlatform: 'Website',
      imageUrl:
          'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=900&auto=format&fit=crop&q=60&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Nnx8Y2hvY29sYXRlJTIwY2FrZXxlbnwwfHwwfHx8MA%3D%3D',
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      ingredients: ['Chocolate', 'Flour', 'Sugar', 'Eggs', 'Butter'],
    ),
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return difference.inDays == 1
          ? '1 day ago'
          : '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return difference.inHours == 1
          ? '1 hour ago'
          : '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return difference.inMinutes == 1
          ? '1 minute ago'
          : '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Imported Recipes'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Navigate to the import recipe screen
              Navigator.pushNamed(context, '/import');
            },
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ],
      ),
      body: Scrollbar(
        controller: _scrollController,
        child: ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: _recipes.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final recipe = _recipes[index];
            return _buildImportedRecipeCard(recipe);
          },
        ),
      ),
    );
  }

  Widget _buildImportedRecipeCard(Recipe recipe) {
    final timeAgo = _getTimeAgo(recipe.createdAt);

    return Card(
      elevation: AppElevation.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recipe card header with image, title and source
          ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                recipe.imageUrl,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[300],
                    child: const Icon(Icons.restaurant, color: Colors.grey),
                  );
                },
              ),
            ),
            title: Text(
              recipe.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              recipe.ingredients.take(3).join(', ') +
                  (recipe.ingredients.length > 3 ? '...' : ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Source and time info
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text(
                  'Imported from ${recipe.source ?? "Unknown"}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const Spacer(),
                Text(
                  timeAgo,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),

          // View recipe button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/recipeDetail',
                    arguments: recipe,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                ),
                child: Text(
                  'View Full Recipe',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: const Icon(Icons.favorite_border),
                  onPressed: () {},
                  tooltip: 'Add to favorites',
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {},
                  tooltip: 'Edit recipe',
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () async {
                    await recipe.share();
                  },
                  tooltip: 'Share recipe',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {},
                  tooltip: 'Delete recipe',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
