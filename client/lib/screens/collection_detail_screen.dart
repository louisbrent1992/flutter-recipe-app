import 'package:flutter/material.dart';
import 'package:recipease/components/custom_app_bar.dart';
import 'package:recipease/components/floating_bottom_bar.dart';
import '../theme/theme.dart';

import 'package:recipease/models/recipe.dart';
import 'package:recipease/models/recipe_collection.dart';
import 'package:recipease/services/collection_service.dart';
import 'package:recipease/screens/add_recipes_to_collection_screen.dart';
import '../components/recipe_card.dart';

class CollectionDetailScreen extends StatefulWidget {
  final RecipeCollection collection;

  const CollectionDetailScreen({super.key, required this.collection});

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late RecipeCollection _collection;
  late ScrollController _scrollController;
  late TextEditingController _searchController;
  bool _isLoading = false;
  List<Recipe> _filteredRecipes = [];
  String _searchQuery = '';
  late CollectionService _collectionService;

  @override
  void initState() {
    super.initState();
    _collection = widget.collection;
    _scrollController = ScrollController();
    _searchController = TextEditingController();
    _filteredRecipes = _collection.recipes;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _filterRecipes(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredRecipes = _collection.recipes;
      } else {
        _filteredRecipes =
            _collection.recipes.where((recipe) {
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

  Future<void> _refreshCollection() async {
    print("Refreshing collection: ${_collection.id}");
    setState(() => _isLoading = true);
    try {
      final updatedCollection = await _collectionService.getCollection(
        _collection.id,
      );
      print("Updated collection: ${updatedCollection?.recipes.length} recipes");
      if (updatedCollection != null && mounted) {
        setState(() {
          _collection = updatedCollection;
          _filteredRecipes = _collection.recipes;
          _filterRecipes(_searchQuery);
        });
        print(
          "Collection updated in state: ${_collection.recipes.length} recipes",
        );
      } else {
        print("Failed to get updated collection");
      }
    } catch (e) {
      print("Error refreshing collection: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing collection: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editCollection() async {
    final TextEditingController nameController = TextEditingController(
      text: _collection.name,
    );

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Collection'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Collection Name',
                    hintText: 'Enter collection name',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                const Text('More editing options coming soon!'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    return;
                  }
                  Navigator.pop(context, {'name': name});
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );

    if (result != null && mounted) {
      setState(() => _isLoading = true);
      try {
        final updatedCollection = await _collectionService.updateCollection(
          _collection.id,
          name: result['name'],
        );

        if (updatedCollection != null && mounted) {
          setState(() => _collection = updatedCollection);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Collection updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating collection: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _removeRecipe(Recipe recipe) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Remove Recipe'),
            content: Text(
              'Are you sure you want to remove "${recipe.title}" from this collection?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                                          foregroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: Theme.of(context).colorScheme.alphaVeryHigh),
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final success = await _collectionService.removeRecipeFromCollection(
          _collection.id,
          recipe.id,
        );

        if (success) {
          await _refreshCollection();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Removed "${recipe.title}" from collection'),
                backgroundColor: Colors.orange,
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () async {
                    await _collectionService.addRecipeToCollection(
                      _collection.id,
                      recipe,
                    );
                    await _refreshCollection();
                  },
                  textColor: Colors.white,
                ),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error removing recipe: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _searchAllRecipes() async {
    // Navigate to the recipe search screen and pass the collection
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => AddRecipesToCollectionScreen(collection: _collection),
      ),
    );

    // Refresh the collection if we got results back
    if (result == true && mounted) {
      await _refreshCollection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: CustomAppBar(
        title: '${_collection.name} Recipes',
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded),
            onPressed: _editCollection,
            tooltip: 'Edit collection',
          ),
        ],
        floatingButtons: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Recipes',
            onPressed:
                widget.collection.name == 'Favorites'
                    ? () => Navigator.pushNamed(context, '/myRecipes')
                    : _searchAllRecipes,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _refreshCollection,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Collection header
                    SliverToBoxAdapter(
                      child: _buildCollectionHeader(colorScheme),
                    ),

                    // Search field
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: _buildSearchField(colorScheme),
                      ),
                    ),

                    // Recipes grid
                    _filteredRecipes.isEmpty
                        ? SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.no_meals,
                                  size: 64,
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'No recipes in this collection yet'
                                      : 'No recipes match your search',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        : SliverPadding(
                          padding: const EdgeInsets.all(16),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.75,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final recipe = _filteredRecipes[index];
                              return RecipeCard(
                                recipe: recipe,
                                showEditButton: true,
                                onTap:
                                    () => Navigator.pushNamed(
                                      context,
                                      '/recipeDetail',
                                      arguments: recipe,
                                    ),
                                onRemove: () => _removeRecipe(recipe),
                                showRemoveButton: true,
                              );
                            }, childCount: _filteredRecipes.length),
                          ),
                        ),
                  ],
                ),
              ),
          FloatingBottomBar(),
        ],
      ),
    );
  }

  Widget _buildCollectionHeader(ColorScheme colorScheme) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _animationController.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _animationController.value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _collection.color.withValues(alpha: 0.2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _collection.color.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_collection.icon, size: 32, color: _collection.color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _collection.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_collection.recipes.length} ${_collection.recipes.length == 1 ? 'recipe' : 'recipes'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(ColorScheme colorScheme) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: (_animationController.value - 0.2).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(
              0,
              20 * (1 - (_animationController.value - 0.2).clamp(0.0, 1.0)),
            ),
            child: child,
          ),
        );
      },
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
              color: colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: colorScheme.primary.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}
