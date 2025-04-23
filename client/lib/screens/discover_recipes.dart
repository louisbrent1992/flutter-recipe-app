import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipease/components/custom_app_bar.dart';
import '../models/recipe.dart';
import '../providers/recipe_provider.dart';
import '../components/recipe_card.dart';

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
  List<String> _availableTags = [];
  bool _isLoading = false;

  final List<String> _difficulties = ['All', 'Easy', 'Medium', 'Hard'];

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    setState(() => _isLoading = true);
    try {
      final recipeProvider = context.read<RecipeProvider>();
      await recipeProvider.loadUserRecipes();

      // Extract unique tags from recipes
      _availableTags = [
        'All',
        ...recipeProvider.userRecipes.expand((recipe) => recipe.tags).toSet(),
      ];
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading recipes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Recipe> _filterRecipes(List<Recipe> recipes) {
    return recipes.where((recipe) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          recipe.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (recipe.description.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ));

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
      appBar: const CustomAppBar(title: 'Discover Recipes'),
      body: Column(
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
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FilterChip(
                            label: Text(difficulty),
                            selected: _selectedDifficulty == difficulty,
                            onSelected: (selected) {
                              setState(() => _selectedDifficulty = difficulty);
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
                          padding: const EdgeInsets.symmetric(horizontal: 4),
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
                if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final filteredRecipes = _filterRecipes(
                  recipeProvider.userRecipes,
                );

                if (filteredRecipes.isEmpty) {
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
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: filteredRecipes.length,
                  itemBuilder: (context, index) {
                    final recipe = filteredRecipes[index];
                    return RecipeCard(
                      recipe: recipe,
                      onTap:
                          () => Navigator.pushNamed(
                            context,
                            '/recipeDetail',
                            arguments: recipe,
                          ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
