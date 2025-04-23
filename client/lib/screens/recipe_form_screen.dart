import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';

class RecipeFormScreen extends StatefulWidget {
  final Recipe? recipe;
  const RecipeFormScreen({super.key, this.recipe});

  @override
  RecipeFormScreenState createState() => RecipeFormScreenState();
}

class RecipeFormScreenState extends State<RecipeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _ingredientsController;
  late TextEditingController _stepsController;
  late TextEditingController _descriptionController;

  static const String titleLabel = 'Recipe Title';
  static const String descriptionLabel = 'Description';
  static const String ingredientsLabel = 'Ingredients (comma separated)';
  static const String stepsLabel = 'Steps (comma separated)';

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _titleController = TextEditingController(text: widget.recipe?.title ?? '');
    _ingredientsController = TextEditingController(
      text: widget.recipe?.ingredients.join(", ") ?? '',
    );
    _stepsController = TextEditingController(
      text: widget.recipe?.instructions.join(", ") ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.recipe?.description ?? '',
    );
  }

  void _saveRecipe() async {
    if (_formKey.currentState!.validate()) {
      Recipe newRecipe = Recipe(
        id: widget.recipe!.id,
        title: _titleController.text,
        ingredients:
            _ingredientsController.text
                .split(',')
                .map((e) => e.trim())
                .toList(),
        instructions:
            _stepsController.text.split(',').map((e) => e.trim()).toList(),
        description: _descriptionController.text,
        imageUrl: widget.recipe?.imageUrl ?? '',
        cookingTime: widget.recipe?.cookingTime ?? '',
        servings: widget.recipe?.servings ?? '',
      );
      if (widget.recipe == null) {
        await RecipeService.createUserRecipe(newRecipe);
      } else {
        await RecipeService.updateUserRecipe(newRecipe);
      }
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _ingredientsController.dispose();
    _stepsController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe == null ? 'Add Recipe' : 'Edit Recipe'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            color: Theme.of(context).colorScheme.onPrimary,
            onPressed: () {
              // Handle favorite action
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: titleLabel),
                validator:
                    (value) =>
                        value == null || value.isEmpty ? 'Enter title' : null,
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: descriptionLabel),
              ),
              TextFormField(
                controller: _ingredientsController,
                decoration: const InputDecoration(labelText: ingredientsLabel),
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Enter ingredients'
                            : null,
              ),
              TextFormField(
                controller: _stepsController,
                decoration: const InputDecoration(labelText: stepsLabel),
                validator:
                    (value) =>
                        value == null || value.isEmpty ? 'Enter steps' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveRecipe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: const Text('Save Recipe'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
