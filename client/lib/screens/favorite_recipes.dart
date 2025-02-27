import 'package:flutter/material.dart';
import 'package:recipease/components/bottom_nav_bar.dart';
import 'package:recipease/models/recipe.dart';

// Assuming the path is correct based on the context provided

class FavoriteRecipesScreen extends StatelessWidget {
  const FavoriteRecipesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Dummy list of favorite recipes
    final List<Recipe> favoriteRecipes = [
      Recipe(
        title: 'Classic Tomato Spaghetti',
        imageUrl:
            'https://images.unsplash.com/photo-1605888969139-42cca4308aa2?q=80&w=685&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
      ),
      Recipe(
        title: 'Creamy Garlic Chicken',
        imageUrl:
            'https://images.unsplash.com/photo-1562967916-eb82221dfb92?q=80&w=685&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
      ),
      Recipe(
        title: 'Vegetarian Pizza',
        imageUrl:
            'https://images.unsplash.com/photo-1694717065203-8cb0de9918f3?w=900&auto=format&fit=crop&q=60&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Mnx8dmVnZXRhcmlhbiUyMHBpenphfGVufDB8fDB8fHww',
      ),
      // Add more recipes as needed
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Favorite Recipes')),
      body: ListView.builder(
        itemCount: favoriteRecipes.length,
        itemBuilder: (context, index) {
          final recipe = favoriteRecipes[index];
          return Padding(
            padding: const EdgeInsets.fromLTRB(40.0, 10.0, 40.0, 10.0),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    color: Colors.black,
                    image: DecorationImage(
                      image: Image.network(recipe.imageUrl).image,
                      fit: BoxFit.cover,
                    ),
                  ),
                  height: 180,
                  width: double.infinity,
                ),
                const SizedBox(height: 8),
                Text(
                  recipe.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/recipeDetail',
                        arguments: recipe,
                      );
                    },

                    child: const Text(
                      'Recipe Details',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}
