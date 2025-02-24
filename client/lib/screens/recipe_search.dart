import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:recipease/components/bottom_nav_bar.dart';

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
        title: Container(
          alignment: Alignment.center,
          height: 40,
          child: TextField(
            textAlignVertical: TextAlignVertical.bottom,
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search for recipes...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
            ),
            onChanged: (value) {
              // Implement search functionality
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // Handle search action
              Navigator.pushNamed(context, '/notifications');
            },
            padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 0, 10),
            iconSize: 30,
          ),

          Container(
            margin: const EdgeInsetsDirectional.fromSTEB(10, 10, 10, 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 1),
            ),

            child: Image.network(
              'https://img.icons8.com/?size=100&id=nSR7D8Yb2tjC&format=png&color=000000',
              fit: BoxFit.cover,
              height: 30,

              // Updated link for profile pic
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Text(
              'Discover Recipes',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: [
                  _buildTrendingRecipe('Pasta with Pesto', 'John Doe'),
                  _buildTrendingRecipe('Grilled Salmon', 'Jane Smith'),
                  _buildTrendingRecipe('Homemade Bread', 'Alice Johnson'),
                  _buildTrendingRecipe('Sushi Platter', 'Bob Williams'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Recommended for you',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildFlavorCard('Vegetarian'),
                _buildFlavorCard('Healthy Eats'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildFlavorCard('Sweet Treats'),
                _buildFlavorCard('Relaxing'),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: const TransparentBtmNavBarCurvedFb1(),
    );
  }

  Widget _buildFlavorCard(String title, [String? subtitle]) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            height: 70,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                if (subtitle != null) Text(subtitle),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrendingRecipe(String title, String author, [String? imageUrl]) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              border: Border.all(color: Colors.black, width: 1),
              borderRadius: const BorderRadius.all(Radius.circular(15)),

              // Updated link for profile pic
            ),
            width: 50,
            height: 50,

            child: Image.network(
              imageUrl ??
                  'https://img.icons8.com/?size=100&id=nSR7D8Yb2tjC&format=png&color=000000',
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10), // Add spacing between image and text
          Expanded(
            child: ListTile(
              title: Text(title),
              subtitle: Text(author),
              trailing: const Icon(Icons.restaurant_menu_outlined),
              onTap: () {
                // Navigate to recipe detail or perform an action
              },
            ),
          ),
        ],
      ),
    );
  }
}
