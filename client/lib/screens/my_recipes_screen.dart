import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipease/models/recipe.dart';
import 'package:recipease/providers/auth_provider.dart';
import 'package:recipease/providers/recipe_provider.dart';
import 'package:recipease/components/custom_app_bar.dart';
import 'package:recipease/components/recipe_card.dart';

class MyRecipesScreen extends StatefulWidget {
  const MyRecipesScreen({super.key});

  @override
  State<MyRecipesScreen> createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends State<MyRecipesScreen> {
  @override
  void initState() {
    super.initState();
    // Load recipes when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.user != null) {
        Provider.of<RecipeProvider>(context, listen: false).loadUserRecipes();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'My Recipes'),

      body: Consumer2<AuthService, RecipeProvider>(
        builder: (context, authService, recipeProvider, _) {
          // Check if user is logged in
          if (authService.user == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Login Required',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You need to login to view and manage your recipes',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/login');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Login',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/register');
                    },
                    child: const Text('Create an Account'),
                  ),
                ],
              ),
            );
          }

          if (recipeProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<Recipe> myRecipes = recipeProvider.userRecipes;

          if (myRecipes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.restaurant_menu,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No recipes yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/recipeEdit');
                    },
                    child: const Text('Create Your First Recipe'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: myRecipes.length,
            itemBuilder: (context, index) {
              final recipe = myRecipes[index];
              return RecipeCard(recipe: recipe, showEditButton: true);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final authService = Provider.of<AuthService>(context, listen: false);
          if (authService.user == null) {
            // Show login dialog if not authenticated
            showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Login Required'),
                    content: const Text('You need to login to create recipes.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/login');
                        },
                        child: const Text('Login'),
                      ),
                    ],
                  ),
            );
          } else {
            Navigator.pushNamed(context, '/import');
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
