import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:recipease/models/recipe.dart';
import 'package:recipease/providers/recipe_provider.dart';
import 'package:recipease/components/custom_app_bar.dart';
import 'package:recipease/components/recipe_card.dart';
import 'package:recipease/components/floating_home_button.dart';
import 'package:recipease/components/floating_add_button.dart';

class MyRecipesScreen extends StatefulWidget {
  const MyRecipesScreen({super.key});

  @override
  State<MyRecipesScreen> createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends State<MyRecipesScreen> {
  final ScrollController _scrollController = ScrollController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDifficulty = 'All';
  String _selectedTag = 'All';
  final List<String> _availableTags = [];
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

  List<Recipe> _filterRecipes(List<Recipe> recipes) {
    return recipes.where((recipe) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          recipe.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          recipe.description.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesDifficulty =
          _selectedDifficulty == 'All' ||
          recipe.difficulty == _selectedDifficulty;

      final matchesTag =
          _selectedTag == 'All' || recipe.tags.contains(_selectedTag);

      return matchesSearch && matchesDifficulty && matchesTag;
    }).toList();
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
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search recipes...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon:
                            _searchQuery.isNotEmpty
                                ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                                : null,
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Text('Difficulty: '),
                          ..._difficulties.map(
                            (difficulty) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: FilterChip(
                                label: Text(difficulty),
                                selected: _selectedDifficulty == difficulty,
                                onSelected: (selected) {
                                  setState(
                                    () => _selectedDifficulty = difficulty,
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Text('Tags: '),
                          ..._availableTags.map(
                            (tag) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: FilterChip(
                                label: Text(tag),
                                selected: _selectedTag == tag,
                                onSelected: (selected) {
                                  setState(() => _selectedTag = tag);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Consumer<RecipeProvider>(
                  builder: (context, recipeProvider, _) {
                    if (recipeProvider.isLoading &&
                        recipeProvider.userRecipes.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final List<Recipe> myRecipes = _filterRecipes(
                      recipeProvider.userRecipes,
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
