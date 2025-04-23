import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipease/models/recipe.dart';
import 'package:recipease/providers/auth_provider.dart';
import 'package:recipease/providers/recipe_provider.dart';
import 'package:recipease/providers/user_profile_provider.dart';
import 'package:recipease/components/custom_app_bar.dart';

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
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      recipe.imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(
                    recipe.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    recipe.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'edit':
                          Navigator.pushNamed(
                            context,
                            '/recipeEdit',
                            arguments: recipe,
                          );
                          break;
                        case 'favorite':
                          final newStatus = !recipe.isFavorite;
                          await recipeProvider.toggleFavorite(
                            recipe.id,
                            newStatus,
                          );
                          if (!context.mounted) return;
                          final userProfileProvider =
                              Provider.of<UserProfileProvider>(
                                context,
                                listen: false,
                              );
                          if (newStatus) {
                            await userProfileProvider.addToFavorites(recipe);
                          } else {
                            await userProfileProvider.removeFromFavorites(
                              recipe,
                            );
                          }
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                newStatus
                                    ? 'Recipe added to favorites'
                                    : 'Recipe removed from favorites',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          break;
                        case 'delete':
                          showDialog(
                            context: context,
                            builder:
                                (context) => AlertDialog(
                                  title: const Text('Delete Recipe'),
                                  content: Text(
                                    'Are you sure you want to delete "${recipe.title}"?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        await recipeProvider.deleteUserRecipe(
                                          recipe.id,
                                        );
                                        // Refresh the list
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Recipe deleted'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                          );
                          break;
                      }
                    },
                    itemBuilder:
                        (BuildContext context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'favorite',
                            child: Row(
                              children: [
                                Icon(
                                  recipe.isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: recipe.isFavorite ? Colors.red : null,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  recipe.isFavorite
                                      ? 'Remove from Favorites'
                                      : 'Add to Favorites',
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete),
                                SizedBox(width: 8),
                                Text('Delete'),
                              ],
                            ),
                          ),
                        ],
                  ),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/recipeDetail',
                      arguments: recipe,
                    );
                  },
                ),
              );
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
