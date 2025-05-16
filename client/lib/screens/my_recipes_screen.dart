import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:recipease/models/recipe.dart';
import 'package:recipease/providers/recipe_provider.dart';
import 'package:recipease/components/custom_app_bar.dart';
import 'package:recipease/components/recipe_card.dart';
import 'package:recipease/components/floating_home_button.dart';
import 'package:recipease/components/floating_add_button.dart';
import 'package:recipease/components/recipe_filter_bar.dart';
import 'package:recipease/mixins/recipe_filter_mixin.dart';

class MyRecipesScreen extends StatefulWidget {
  const MyRecipesScreen({super.key});

  @override
  State<MyRecipesScreen> createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends State<MyRecipesScreen>
    with RecipeFilterMixin {
  final ScrollController _scrollController = ScrollController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDifficulty = 'All';
  String _selectedTag = 'All';
  final List<String> _availableTags = [
    'All',
    'Breakfast',
    'Lunch',
    'Dinner',
    'Dessert',
    'Vegetarian',
    'Vegan',
    'Gluten-Free',
    'Quick & Easy',
    'Healthy',
    'Comfort Food',
    'Italian',
    'Mexican',
    'Asian',
    'Mediterranean',
  ];
  final List<String> _difficulties = ['All', 'Easy', 'Medium', 'Hard'];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    // Initial load of recipes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final recipeProvider = Provider.of<RecipeProvider>(
        context,
        listen: false,
      );
      recipeProvider.loadUserRecipes();
      _updateAvailableTags(recipeProvider.userRecipes);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _searchController.dispose();
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

  void _updateAvailableTags(List<Recipe> recipes) {
    final newTags =
        recipes.expand((recipe) => recipe.tags).toSet().toList()..sort();
    if (!listEquals(_availableTags, newTags)) {
      setState(() {
        _availableTags.clear();
        _availableTags.add('All');
        _availableTags.addAll(newTags);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'My Recipes'),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: RecipeFilterBar(
                  searchController: _searchController,
                  searchQuery: _searchQuery,
                  selectedDifficulty: _selectedDifficulty,
                  selectedTag: _selectedTag,
                  difficulties: _difficulties,
                  availableTags: _availableTags,
                  onSearchChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                  onDifficultySelected: (difficulty) {
                    setState(() => _selectedDifficulty = difficulty);
                  },
                  onTagSelected: (tag) {
                    setState(() => _selectedTag = tag);
                  },
                ),
              ),
              Expanded(
                child: Consumer<RecipeProvider>(
                  builder: (context, recipeProvider, _) {
                    if (recipeProvider.isLoading &&
                        recipeProvider.userRecipes.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final List<Recipe> myRecipes = filterRecipes(
                      recipeProvider.userRecipes,
                      searchQuery: _searchQuery,
                      selectedDifficulty: _selectedDifficulty,
                      selectedTag: _selectedTag,
                    );

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
                              'No recipes found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
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

                    return Scrollbar(
                      controller: _scrollController,
                      child: GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.75,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                        itemCount:
                            myRecipes.length +
                            (recipeProvider.isLoading ||
                                    recipeProvider.hasNextPage
                                ? 1
                                : 0),
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
                              return const SizedBox.shrink();
                            }
                            return const SizedBox.shrink();
                          }

                          final recipe = myRecipes[index];
                          return RecipeCard(
                            recipe: recipe,
                            showEditButton: true,
                            showRemoveButton: true,
                            onTap:
                                () => Navigator.pushNamed(
                                  context,
                                  '/recipeDetail',
                                  arguments: recipe,
                                ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const FloatingHomeButton(),
          const FloatingAddButton(),
        ],
      ),
    );
  }
}
