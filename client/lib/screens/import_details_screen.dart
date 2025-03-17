import 'package:flutter/material.dart';
import 'package:recipease/components/app_bar.dart';
import 'package:recipease/components/nav_drawer.dart';
import 'package:recipease/components/editable_recipe_field.dart';
import 'package:recipease/components/recipe_tags.dart';
import 'package:recipease/models/recipe.dart';
import 'package:recipease/services/api_service.dart';

class ImportDetailsScreen extends StatefulWidget {
  const ImportDetailsScreen({super.key});

  @override
  State<ImportDetailsScreen> createState() => _ImportDetailsScreenState();
}

class _ImportDetailsScreenState extends State<ImportDetailsScreen> {
  Recipe? currentRecipe;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _ingredientsController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  final TextEditingController _cookingTimeController = TextEditingController();
  final TextEditingController _servingsController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  void _updateRecipe({
    String? title,
    String? source,
    String? description,
    String? imageUrl,
    List<String>? ingredients,
    List<String>? instructions,
    String? cookingTime,
    String? difficulty,
    String? servings,
    List<String>? tags,
  }) {
    setState(() {
      currentRecipe = Recipe(
        id: currentRecipe!.id,
        title: title ?? currentRecipe!.title,
        ingredients: ingredients ?? currentRecipe!.ingredients,
        instructions: instructions ?? currentRecipe!.instructions,
        description: description ?? currentRecipe!.description,
        imageUrl: imageUrl ?? currentRecipe!.imageUrl,
        cookingTime: cookingTime ?? currentRecipe!.cookingTime,
        difficulty: difficulty ?? currentRecipe!.difficulty,
        servings: servings ?? currentRecipe!.servings,
        source: source ?? currentRecipe!.source,
        tags: tags ?? currentRecipe!.tags,
      );
    });
  }

  void _saveRecipe(Recipe currentRecipe) async {
    Recipe recipe = await ApiService.createRecipe(currentRecipe);
    setState(() {
      this.currentRecipe = recipe;
    });
    if (mounted) {
      Navigator.pushNamed(context, '/importList', arguments: currentRecipe);
    }
  }

  void _autoFillRecipe(Recipe currentRecipe) async {
    Recipe recipe = await ApiService.fillSocialRecipe(currentRecipe);
    setState(() {
      this.currentRecipe = recipe;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _sourceController.dispose();
    _descriptionController.dispose();
    _ingredientsController.dispose();
    _instructionsController.dispose();
    _cookingTimeController.dispose();
    _servingsController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Import Recipe'),
      drawer: const NavDrawer(),
      body: SafeArea(
        child: Scrollbar(
          thumbVisibility: true,
          thickness: 10,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recipe Header with Image
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 250,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            currentRecipe!.imageUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      EditableRecipeField(
                        label: 'Title',
                        controller: _titleController,
                        value: currentRecipe!.title,
                        hintText: 'Enter recipe title',
                        onSave: (value) {
                          setState(() {
                            _updateRecipe(title: _titleController.text);
                            _titleController.text = value;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      EditableRecipeField(
                        label: 'Source',
                        controller: _sourceController,
                        value: currentRecipe!.source,
                        hintText: 'Enter recipe source',
                        onSave: (value) {
                          setState(() {
                            _updateRecipe(source: value);
                            _sourceController.text = value;
                          });
                        },
                        customDisplay: Text(
                          'Source: ${currentRecipe!.source}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Description
                  EditableRecipeField(
                    label: 'Description',
                    controller: _descriptionController,
                    value: currentRecipe!.description,
                    hintText: 'Enter recipe description',
                    isMultiline: true,
                    onSave: (value) {
                      setState(() {
                        _updateRecipe(description: value);
                        _descriptionController.text = value;
                      });
                    },
                  ),
                  const SizedBox(height: 15),

                  // Ingredients
                  EditableRecipeField(
                    label: 'Ingredients',
                    controller: _ingredientsController,
                    value: currentRecipe!.ingredients.join('\n'),
                    hintText: 'Enter ingredients (one per line)',
                    isMultiline: true,
                    onSave: (value) {
                      final ingredients =
                          value
                              .split('\n')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList();
                      setState(() {
                        _updateRecipe(ingredients: ingredients);
                        _ingredientsController.text = value;
                      });
                    },
                    customDisplay: Text(_ingredientsController.text),
                  ),
                  const SizedBox(height: 15),

                  // Instructions
                  EditableRecipeField(
                    label: 'Instructions',
                    value: currentRecipe!.instructions.join('\n'),
                    controller: _instructionsController,
                    hintText: 'Enter instructions (one per line)',
                    isMultiline: true,
                    onSave: (value) {
                      final instructions =
                          value
                              .split('\n')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList();
                      setState(() {
                        _updateRecipe(instructions: instructions);
                        _instructionsController.text = value;
                      });
                    },
                    customDisplay: Text(_instructionsController.text),
                  ),
                  const SizedBox(height: 15),

                  // Cooking Details
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: EditableRecipeField(
                          label: 'Cooking Time',
                          controller: _cookingTimeController,
                          value: '${currentRecipe!.cookingTime} minutes',
                          hintText: 'Enter cooking time in minutes',
                          onSave: (value) {
                            setState(() {
                              _updateRecipe(cookingTime: value);
                              _cookingTimeController.text = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: EditableRecipeField(
                          label: 'Servings',
                          controller: _servingsController,
                          value: currentRecipe!.servings,
                          hintText: 'Enter number of servings',
                          onSave: (value) {
                            setState(() {
                              _updateRecipe(servings: value);
                              _servingsController.text = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // Tags
                  RecipeTags(
                    tags: currentRecipe?.tags ?? [],
                    onAddTag: (tag) {
                      if (!currentRecipe!.tags.contains(tag)) {
                        _updateRecipe(tags: [...currentRecipe!.tags, tag]);
                      }
                    },
                    onDeleteTag: (index) {
                      final newTags = List<String>.from(currentRecipe!.tags)
                        ..removeAt(index);
                      _updateRecipe(tags: newTags);
                    },
                  ),
                  const SizedBox(height: 15),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.secondary,
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _autoFillRecipe(currentRecipe!),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.auto_awesome, color: Colors.white),
                            Text(
                              'Autofill',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _saveRecipe(currentRecipe!),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.tertiary,
                        ),
                        child: Text(
                          'Save',
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onTertiary
                                            .computeLuminance() >
                                        0.5
                                    ? Colors.black
                                    : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
