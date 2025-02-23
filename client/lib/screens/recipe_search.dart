import 'package:flutter/material.dart';

class RecipeSearchScreen extends StatefulWidget {
  const RecipeSearchScreen({super.key});

  @override
  RecipeSearchScreenState createState() => RecipeSearchScreenState();
}

class RecipeSearchScreenState extends State<RecipeSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<String> recipes = [
    "Pasta with Pesto",
    "Grilled Salmon",
    "Homemade Bread",
    "Sushi Platter",
  ];
  List<String> recommendedCategories = [
    "Vegetarian",
    "Healthy Eats",
    "Sweet Treats",
    "Relaxing",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Recipes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // Implement filter functionality
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for recipes...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onChanged: (value) {
                // Implement search functionality
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: recipes.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(recipes[index]),
                    subtitle: Text('Description for ${recipes[index]}'),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () {
                      // Navigate to recipe detail screen
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Recommended for you',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              children:
                  recommendedCategories.map((category) {
                    return Chip(
                      label: Text(category),
                      backgroundColor: Colors.grey[200],

                      // Implement category filter functionality
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
