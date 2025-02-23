import 'package:flutter/material.dart';
import 'package:recipease/components/bottom_nav_bar.dart';
// Removed the import for bottom_nav_bar since it doesn't exist

class NewHomeScreen extends StatelessWidget {
  const NewHomeScreen({Key? key})
    : super(key: key); // Updated constructor for clarity

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Good afternoon, chef!')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          // Make the screen scrollable
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Discover new flavors',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildFlavorCard('Quick Cooking'),
                  _buildFlavorCard('Soothing Morning brew'),
                  _buildFlavorCard('Weekend Kitchen vibes'),
                ],
              ),
              const SizedBox(height: 15),
              const Text(
                'Personalized picks',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildFlavorCard('Your favorites', 'Culinary inspirations'),
                  _buildFlavorCard('Top picks', "Chef's selection"),
                ],
              ),
              const SizedBox(height: 15),
              const Text(
                'Trending recipes',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              _buildTrendingRecipe('Healthy treats', 'Samantha'),
              _buildTrendingRecipe('All-time favorites', 'Ethan'),
              _buildTrendingRecipe('Cooking together', 'Family recipes'),
              _buildTrendingRecipe('Healthy treats', 'Samantha'),
              _buildTrendingRecipe('All-time favorites', 'Ethan'),
              _buildTrendingRecipe('Cooking together', 'Family recipes'),
              _buildTrendingRecipe('Healthy treats', 'Samantha'),
              _buildTrendingRecipe('All-time favorites', 'Ethan'),
              _buildTrendingRecipe('Cooking together', 'Family recipes'),
            ],
          ),
        ),
      ),
      extendBody: true,
      bottomNavigationBar: const TransparentBtmNavBarCurvedFb1(),
    );
  }

  Widget _buildFlavorCard(String title, [String? subtitle]) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              if (subtitle != null) Text(subtitle),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendingRecipe(String title, String author) {
    return ListTile(
      title: Text(title),
      subtitle: Text(author),
      trailing: const Icon(Icons.arrow_forward),
      onTap: () {
        // Navigate to recipe detail or perform an action
      },
    );
  }
}
