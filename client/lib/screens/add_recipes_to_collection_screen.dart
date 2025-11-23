import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:recipease/components/custom_app_bar.dart';
import 'package:recipease/models/recipe.dart';
import 'package:recipease/models/recipe_collection.dart';
import 'package:recipease/providers/recipe_provider.dart';
import 'package:recipease/services/collection_service.dart';
import 'package:recipease/components/html_description.dart';

class AddRecipesToCollectionScreen extends StatefulWidget {
  final RecipeCollection collection;

  const AddRecipesToCollectionScreen({super.key, required this.collection});

  @override
  State<AddRecipesToCollectionScreen> createState() =>
      _AddRecipesToCollectionScreenState();
}

class _AddRecipesToCollectionScreenState
    extends State<AddRecipesToCollectionScreen> {
  late RecipeCollection _collection;
  final TextEditingController _searchController = TextEditingController();
  final List<Recipe> _selectedRecipes = [];
  List<Recipe> _allRecipes = [];
  List<Recipe> _filteredRecipes = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _collection = widget.collection;
    // Defer provider access until after the build phase
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _loadRecipes();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);

    try {
      final recipeProvider = Provider.of<RecipeProvider>(
        context,
        listen: false,
      );
      await recipeProvider.loadUserRecipes();

      if (!mounted) return;

      setState(() {
        // Get all user recipes
        _allRecipes = recipeProvider.userRecipes;

        // Filter out recipes that are already in the collection
        final collectionRecipeIds =
            _collection.recipes.map((r) => r.id).toList();
        _allRecipes =
            _allRecipes
                .where((r) => !collectionRecipeIds.contains(r.id))
                .toList();

        // Initialize filtered recipes to all recipes
        _filteredRecipes = _allRecipes;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading recipes: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterRecipes(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredRecipes = _allRecipes;
      } else {
        _filteredRecipes =
            _allRecipes.where((recipe) {
              return recipe.title.toLowerCase().contains(_searchQuery) ||
                  recipe.description.toLowerCase().contains(_searchQuery) ||
                  recipe.ingredients.any(
                    (i) => i.toLowerCase().contains(_searchQuery),
                  ) ||
                  recipe.tags.any(
                    (t) => t.toLowerCase().contains(_searchQuery),
                  );
            }).toList();
      }
    });
  }

  void _toggleRecipeSelection(Recipe recipe) {
    setState(() {
      if (_selectedRecipes.any((r) => r.id == recipe.id)) {
        _selectedRecipes.removeWhere((r) => r.id == recipe.id);
      } else {
        _selectedRecipes.add(recipe);
      }
    });
  }

  Future<void> _addSelectedRecipesToCollection() async {
    final collectionService = context.read<CollectionService>();
    if (_selectedRecipes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one recipe'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    print(
      "Adding ${_selectedRecipes.length} recipes to collection ${_collection.id}",
    );
    setState(() => _isLoading = true);

    bool success = true;
    try {
      // Add each selected recipe to the collection
      for (final recipe in _selectedRecipes) {
        print("Adding recipe: ${recipe.id} - ${recipe.title}");
        final result = await collectionService.addRecipeToCollection(
          _collection.id,
          recipe,
        );
        if (!result) {
          print("Failed to add recipe: ${recipe.id}");
          success = false;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added ${_selectedRecipes.length} ${_selectedRecipes.length == 1 ? 'recipe' : 'recipes'} to collection',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Return true to indicate recipes were added (even if some failed)
        print("Returning to previous screen with result: $success");
        Navigator.pop(context, true);
      }
    } catch (e) {
      print("Error adding recipes: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding recipes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Add',
        fullTitle: 'Add to Collection',
        actions: [
          if (_selectedRecipes.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  '${_selectedRecipes.length} selected',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadRecipes,
                child: Stack(
                  children: [
                    Column(
                      children: [
                        // Search field
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: TextField(
                            controller: _searchController,
                            onChanged: _filterRecipes,
                            decoration: InputDecoration(
                              hintText: 'Search recipes...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon:
                                  _searchQuery.isNotEmpty
                                      ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                          _filterRecipes('');
                                        },
                                      )
                                      : null,
                              filled: true,
                              fillColor: colorScheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: colorScheme.outline.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.5,
                                  ),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Recipes list or empty state
                        Expanded(
                          child:
                              _filteredRecipes.isEmpty
                                  ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.no_meals,
                                          size: 64,
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.2),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          _searchQuery.isEmpty
                                              ? 'No recipes available to add'
                                              : 'No recipes match your search',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  : ListView.builder(
                                    itemCount: _filteredRecipes.length,
                                    padding: const EdgeInsets.only(bottom: 80),
                                    itemBuilder: (context, index) {
                                      final recipe = _filteredRecipes[index];
                                      final isSelected = _selectedRecipes.any(
                                        (r) => r.id == recipe.id,
                                      );

                                      return ListTile(
                                        leading: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.network(
                                            recipe.imageUrl,
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Container(
                                                      width: 60,
                                                      height: 60,
                                                      color: Colors.black54,
                                                      child: Icon(
                                                        color:
                                                            Theme.of(context)
                                                                .colorScheme
                                                                .primary,
                                                        Icons
                                                            .restaurant_rounded,
                                                        size: 30,
                                                      ),
                                                    ),
                                          ),
                                        ),
                                        title: Text(
                                          recipe.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: HtmlDescription(
                                          htmlContent: recipe.description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,

                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.bodyMedium,
                                        ),
                                        trailing: Checkbox(
                                          value: isSelected,
                                          onChanged:
                                              (value) => _toggleRecipeSelection(
                                                recipe,
                                              ),
                                          activeColor: colorScheme.primary,
                                        ),
                                        onTap:
                                            () =>
                                                _toggleRecipeSelection(recipe),
                                        selected: isSelected,
                                        selectedTileColor: colorScheme
                                            .primaryContainer
                                            .withValues(alpha: 0.1),
                                      );
                                    },
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      floatingActionButton:
          _selectedRecipes.isEmpty
              ? null
              : FloatingActionButton.extended(
                onPressed: _addSelectedRecipesToCollection,
                label: const Text('Add to Collection'),
                icon: const Icon(Icons.add_circle_rounded),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
    );
  }
}
