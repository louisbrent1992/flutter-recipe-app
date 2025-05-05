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
  final ScrollController _scrollController = ScrollController();

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

    // Add scroll listener for infinite scroll
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final recipeProvider = Provider.of<RecipeProvider>(
        context,
        listen: false,
      );
      if (recipeProvider.hasNextPage && !recipeProvider.isLoading) {
        recipeProvider.loadNextPage();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'My Recipes'),
      body: Consumer<RecipeProvider>(
        builder: (context, recipeProvider, _) {
          if (recipeProvider.isLoading && recipeProvider.userRecipes.isEmpty) {
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

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: myRecipes.length + 1, // +1 for loading indicator
                  itemBuilder: (context, index) {
                    if (index == myRecipes.length) {
                      if (recipeProvider.isLoading) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      if (!recipeProvider.hasNextPage) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('No more recipes'),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }
                    final recipe = myRecipes[index];
                    return RecipeCard(
                      recipe: recipe,
                      showEditButton: true,
                      showRemoveButton: true,
                    );
                  },
                ),
              ),
              if (recipeProvider.totalPages > 1)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed:
                            recipeProvider.hasPrevPage
                                ? () => recipeProvider.loadPrevPage()
                                : null,
                      ),
                      Text(
                        'Page ${recipeProvider.currentPage} of ${recipeProvider.totalPages}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed:
                            recipeProvider.hasNextPage
                                ? () => recipeProvider.loadNextPage()
                                : null,
                      ),
                    ],
                  ),
                ),
            ],
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
