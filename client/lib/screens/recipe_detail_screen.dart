import 'package:flutter/material.dart';
import 'package:recipease/models/recipe.dart';

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({Key? key, required this.recipe}) : super(key: key);

  final Recipe recipe;

  @override
  RecipeDetailScreenState createState() => RecipeDetailScreenState();
}

class RecipeDetailScreenState extends State<RecipeDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe.title),

        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () {
              // Handle favorite action
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // Handle share action
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 0.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              SizedBox(
                height: 300,
                width: double.infinity,
                child: Image.network(widget.recipe.imageUrl, fit: BoxFit.cover),
              ),
              const SizedBox(height: 10),
              SelectableText(
                widget.recipe.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.recipe.description,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer, size: 18),
                      const SizedBox(width: 8),
                      Text(widget.recipe.cookingTime),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.people, size: 18),
                      const SizedBox(width: 8),
                      Text('Serves ${widget.recipe.servings}'),
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
              ...widget.recipe.ingredients.map(
                (ingredient) => Text('- $ingredient'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Instructions:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...widget.recipe.steps.asMap().entries.map(
                (entry) => Text('${entry.key + 1}. ${entry.value}'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),

      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color.fromARGB(10, 0, 0, 0),
          // Set the background color to transparent (255, 0, 0, 0)
        ),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,

          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1),
                borderRadius: BorderRadius.circular(10),
                color: Colors.black,
              ),
              child: const Row(
                spacing: 6,
                children: [
                  Icon(Icons.favorite, size: 18, color: Colors.white),

                  Text('Favorite', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1),
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
              ),
              child: const Row(
                spacing: 6,
                children: [
                  Icon(Icons.share_rounded, size: 18, color: Colors.black),
                  Text('Share', style: TextStyle(color: Colors.black)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
