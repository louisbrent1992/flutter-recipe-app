import 'package:flutter/material.dart';

class DiscoverRecipeScreen extends StatelessWidget {
  const DiscoverRecipeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New Recipes Daily',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildRecipeCard('Explore', '1 Recipe', '3 Ratings', Icons.star),
            const SizedBox(height: 16),
            _buildRecipeCard(
              'Top Picks',
              '2 Recommendations',
              'Morning',
              Icons.recommend,
            ),
            const SizedBox(height: 16),
            _buildRecipeCard(
              'Favorites',
              'Trending Now',
              'Morning',
              Icons.favorite,
            ),
            const SizedBox(height: 20),
            const Text(
              'Featured Recipes',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildFeaturedRecipe('Tasty Meals', 'Popular Dishes'),
            _buildFeaturedRecipe('Special Diets', 'Diet Plans'),
            _buildFeaturedRecipe('International', 'Global Cuisine'),
            _buildFeaturedRecipe('Weeknight', 'Quick Meals'),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeCard(
    String title,
    String subtitle,
    String time,
    IconData icon,
  ) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Text(time), Icon(icon)],
        ),
        onTap: () {
          // Navigate to the respective recipe details
        },
      ),
    );
  }

  Widget _buildFeaturedRecipe(String title, String subtitle) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward),
      onTap: () {
        // Navigate to the featured recipe details
      },
    );
  }
}
