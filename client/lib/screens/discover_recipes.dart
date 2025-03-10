import 'package:flutter/material.dart';
import 'package:recipease/components/flavor_card.dart';
import 'package:recipease/components/trending_recipe_card.dart';

class DiscoverRecipesScreen extends StatefulWidget {
  const DiscoverRecipesScreen({super.key});

  @override
  DiscoverRecipesScreenState createState() => DiscoverRecipesScreenState();
}

class DiscoverRecipesScreenState extends State<DiscoverRecipesScreen> {
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          textAlignVertical: TextAlignVertical.center,
          controller: _searchController,
          decoration: const InputDecoration(
            border: InputBorder.none,
            alignLabelWithHint: true,
            hintText: 'Search for recipes...',
            hintStyle: TextStyle(color: Colors.white),
            prefixIcon: Icon(Icons.search, color: Colors.white),
          ),
          cursorColor: Theme.of(context).colorScheme.secondary,
          cursorHeight: 18,
          onChanged: (value) {
            // Implement search functionality
          },
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.person,
              color: Theme.of(context).colorScheme.onTertiary,
            ),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Discover Recipes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 10),
              const Expanded(
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        TrendingRecipeCard(
                          title: 'Pasta with Pesto',
                          author: 'John Doe',
                        ),
                        TrendingRecipeCard(
                          title: 'Grilled Salmon',
                          author: 'Jane Smith',
                        ),
                        TrendingRecipeCard(
                          title: 'Homemade Bread',
                          author: 'Alice Johnson',
                        ),
                        TrendingRecipeCard(
                          title: 'Sushi Platter',
                          author: 'Bob Williams',
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Text(
                'Recommended for you',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),

              const SizedBox(height: 8),
              const Row(
                children: [
                  FlavorCard(
                    title: 'Sweet Treats',
                    subtitle: null,
                    imageUrl:
                        'https://images.unsplash.com/photo-1534119428213-bd2626145164?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MTJ8fHN3ZWV0JTIwdHJlYXRzfGVufDB8fDB8fHww',
                  ),
                  FlavorCard(
                    title: 'Relaxing',
                    subtitle: null,
                    imageUrl:
                        'https://images.unsplash.com/photo-1490645935967-10de6ba17061?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxzZWFyY2h8OHx8aGVhbHRoeXxlbnwwfHwwfHx8MA%3D%3D',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
