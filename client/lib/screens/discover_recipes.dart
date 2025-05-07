import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipease/components/custom_app_bar.dart';
import '../providers/recipe_provider.dart';
import '../components/recipe_card.dart';
import '../components/floating_home_button.dart';

class DiscoverRecipesScreen extends StatefulWidget {
  const DiscoverRecipesScreen({super.key});

  @override
  State<DiscoverRecipesScreen> createState() => _DiscoverRecipesScreenState();
}

class _DiscoverRecipesScreenState extends State<DiscoverRecipesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDifficulty = 'All';
  String _selectedTag = 'All';
  final List<String> _difficulties = ['All', 'Easy', 'Medium', 'Hard'];
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

  @override
  void initState() {
    super.initState();
    _searchRecipes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _searchRecipes() {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    recipeProvider.searchExternalRecipes(
      query: _searchQuery.isEmpty ? null : _searchQuery,
      difficulty: _selectedDifficulty == 'All' ? null : _selectedDifficulty,
      tag: _selectedTag == 'All' ? null : _selectedTag,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Discover Recipes'),
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
                                    _searchRecipes();
                                  },
                                )
                                : null,
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                        _searchRecipes();
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
                                  _searchRecipes();
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
                                  _searchRecipes();
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
                    if (recipeProvider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (recipeProvider.error != null) {
                      return Center(
                        child: Text(
                          recipeProvider.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    final recipes = recipeProvider.generatedRecipes;

                    if (recipes.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No recipes found',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try adjusting your search or filters',
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemCount: recipes.length,
                      itemBuilder: (context, index) {
                        final recipe = recipes[index];
                        return RecipeCard(
                          recipe: recipe,
                          showSaveButton: true,
                          onSave: () async {
                            final scaffoldMessenger = ScaffoldMessenger.of(
                              context,
                            );
                            await recipeProvider.saveGeneratedRecipe(recipe);
                            if (mounted) {
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Recipe saved to your collection!',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          const FloatingHomeButton(),
        ],
      ),
    );
  }
}
