import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipease/components/custom_app_bar.dart';
import 'package:recipease/providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import '../components/recipe_card.dart';

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
        Provider.of<UserProfileProvider>(
          context,
          listen: false,
        ).getFavoriteRecipes();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Favorite Recipes'),
      body: Consumer<UserProfileProvider>(
        builder: (context, profile, _) {
          if (profile.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (profile.favoriteRecipes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No favorite recipes yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add recipes to your favorites to see them here',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return Scrollbar(
            thumbVisibility: true,
            thickness: 10,
            controller: _scrollController,
            child: SingleChildScrollView(
              controller: _scrollController,
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: profile.favoriteRecipes.length,
                itemBuilder: (context, index) {
                  final recipe = profile.favoriteRecipes[index];
                  return RecipeCard(
                    recipe: recipe,
                    showEditButton: true,
                    showFavoriteButton: false,
                    showRemoveButton: true,
                    onRemove: () {
                      Provider.of<UserProfileProvider>(
                        context,
                        listen: false,
                      ).removeFromFavorites(recipe);
                    },
                    onTap:
                        () => Navigator.pushNamed(
                          context,
                          '/recipeDetail',
                          arguments: recipe,
                        ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
