import 'package:flutter/material.dart';
import 'package:recipease/components/custom_app_bar.dart';
import 'package:recipease/components/floating_add_button.dart';
import 'package:recipease/components/floating_home_button.dart';
import 'package:recipease/models/recipe_collection.dart';
import 'package:recipease/services/collection_service.dart';
import '../providers/recipe_provider.dart';
import '../services/recipe_service.dart';
import '../theme/theme.dart';

class RecipeCollectionScreen extends StatefulWidget {
  const RecipeCollectionScreen({super.key});

  @override
  State<RecipeCollectionScreen> createState() =>
      _RecipeCollectionsScreenState();
}

class _RecipeCollectionsScreenState extends State<RecipeCollectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final TextEditingController _categoryNameController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  List<RecipeCollection> _collections = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _animationController.forward();

    // Load collections
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    setState(() => _isLoading = true);

    try {
      // Fetch collections using the service
      final collections = await CollectionService.getCollections();

      if (mounted) {
        setState(() {
          _collections = collections;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error loading collections: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddCategoryDialog() {
    _categoryNameController.clear();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Name Your Collection'),
            elevation: AppElevation.dialog,
            content: Column(
              children: [
                TextField(
                  controller: _categoryNameController,
                  decoration: const InputDecoration(
                    hintText: 'Enter category name',
                    labelText: 'Category Name',
                  ),
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  _addCategory(_categoryNameController.text);
                  Navigator.pop(context);
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  Future<void> _addCategory(String name) async {
    if (name.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final newCollection = await CollectionService.createCollection(name);

      if (newCollection != null) {
        // Refresh collections to show the new one
        await _loadCollections();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Category "$name" added'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding category: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteCategory(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Collection'),
            content: Text(
              'Are you sure you want to delete the collection "$name"? This action cannot be undone.',
            ),
            contentTextStyle: Theme.of(context).textTheme.bodySmall,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final success = await CollectionService.deleteCollection(id);
        if (success) {
          await _loadCollections();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Collection "$name" deleted'),
                backgroundColor: Colors.orange,
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () async {
                    await CollectionService.createCollection(name);
                    await _loadCollections();
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
              content: Text('Error deleting collection: $e'),
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

  @override
  void dispose() {
    _animationController.dispose();
    _categoryNameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Recipe Collections'),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Background decoration
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.surface,
                      colorScheme.surface.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),

            // Main content
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                  onRefresh: _loadCollections,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header section
                          _buildHeader(colorScheme),

                          const SizedBox(height: 24),

                          // Grid of categories
                          _buildCategoriesGrid(colorScheme),
                        ],
                      ),
                    ),
                  ),
                ),

            // Add category FAB
            FloatingAddButton(onPressed: _showAddCategoryDialog),
            const FloatingHomeButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: (_animationController.value).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(
              0,
              20 * (1 - _animationController.value.clamp(0.0, 1.0)),
            ),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.collections_bookmark_rounded,
                    size: 32,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recipe Collections',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Organize your recipes into categories',
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
        ],
      ),
    );
  }

  Widget _buildCategoriesGrid(ColorScheme colorScheme) {
    if (_collections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_outlined,
              size: 64,
              color: colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No collections yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first collection by tapping the + button',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: (_animationController.value - 0.2).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(
              0,
              30 * (1 - (_animationController.value - 0.2).clamp(0.0, 1.0)),
            ),
            child: child,
          ),
        );
      },
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _collections.length,
        itemBuilder: (context, index) {
          final collection = _collections[index];

          return _buildCategoryCard(
            collection: collection,
            colorScheme: colorScheme,
          );
        },
      ),
    );
  }

  Widget _buildCategoryCard({
    required RecipeCollection collection,
    required ColorScheme colorScheme,
  }) {
    return Card(
      elevation: AppElevation.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          // Navigate to collection detail screen
          Navigator.pushNamed(
            context,
            '/collectionDetail',
            arguments: collection,
          ).then((_) => _loadCollections()); // Refresh after returning
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: collection.color.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      collection.icon,
                      color: collection.color,
                      size: 28,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed:
                        () => _deleteCategory(collection.id, collection.name),
                    tooltip: 'Delete category',
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                collection.name,
                style: Theme.of(context).textTheme.headlineSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.book, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${collection.recipes.length} ${collection.recipes.length == 1 ? 'recipe' : 'recipes'}',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
