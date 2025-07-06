import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipease/components/custom_app_bar.dart';

import 'package:recipease/providers/auth_provider.dart';
import '../providers/recipe_provider.dart';
import '../components/recipe_card.dart';
import '../components/floating_bottom_bar.dart';

class FavoriteRecipesScreen extends StatefulWidget {
  const FavoriteRecipesScreen({super.key});

  @override
  State<FavoriteRecipesScreen> createState() => _FavoriteRecipesScreenState();
}

class _FavoriteRecipesScreenState extends State<FavoriteRecipesScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Load favorite recipes when the screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.user != null) {
        Provider.of<RecipeProvider>(
          context,
          listen: false,
        ).loadFavoriteRecipes();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Favorite Recipes',
        floatingButtons: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'My Recipes',
            onPressed: () => Navigator.pushNamed(context, '/myRecipes'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<RecipeProvider>(
              builder: (context, recipeProvider, _) {
                if (recipeProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (recipeProvider.favoriteRecipes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.favorite_border,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No favorite recipes yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: recipeProvider.favoriteRecipes.length,
                  itemBuilder: (context, index) {
                    final recipe = recipeProvider.favoriteRecipes[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: RecipeCard(
                        recipe: recipe,
                        showEditButton: false,
                        showFavoriteButton: true,
                        showRemoveButton: true,
                        onTap:
                            () => Navigator.pushNamed(
                              context,
                              '/recipeDetail',
                              arguments: recipe,
                            ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          FloatingBottomBar(),
        ],
      ),
    );
  }
}
