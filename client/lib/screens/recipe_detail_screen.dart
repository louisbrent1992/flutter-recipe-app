import 'package:flutter/material.dart';
import 'package:recipease/models/recipe.dart';

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({super.key, required this.recipe});

  final Recipe? recipe;

  @override
  RecipeDetailScreenState createState() => RecipeDetailScreenState();
}

class RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.recipe?.title ?? 'Recipe Detail',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            color: Theme.of(context).colorScheme.onPrimary,
            onPressed: () {
              // Handle favorite action
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            color: Theme.of(context).colorScheme.onPrimary,
            onPressed: () {
              // Handle share action
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 0.0),
        child: Scrollbar(
          thumbVisibility: true,
          thickness: 10,
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                SizedBox(
                  height: 300,
                  width: double.infinity,
                  child: Image.network(
                    widget.recipe?.imageUrl ?? '',
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 10),
                SelectableText(
                  widget.recipe?.title ?? 'No Title',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.recipe?.description ?? 'No Description',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.timer, size: 18),
                        const SizedBox(width: 8),
                        Text(widget.recipe?.cookingTime ?? 'No Cooking Time'),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.people, size: 18),
                        const SizedBox(width: 8),
                        Text('Serves ${widget.recipe?.servings ?? 0}'),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ingredients:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...widget.recipe?.ingredients.map(
                      (ingredient) => Text('- $ingredient'),
                    ) ??
                    [],
                const SizedBox(height: 16),
                const Text(
                  'Instructions:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...widget.recipe?.instructions.asMap().entries.map(
                      (entry) => Text('${entry.key + 1}. ${entry.value}'),
                    ) ??
                    [],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,

          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(10),
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.favorite,
                    size: 18,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  Text(
                    'Favorite',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(10),
                color: Theme.of(context).colorScheme.surface,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.share_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  Text(
                    'Share',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
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
}
