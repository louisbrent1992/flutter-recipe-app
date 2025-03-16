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
  late Recipe currentRecipe;
  final TextEditingController _titleController = TextEditingController();
  bool _isEditingTitle = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!mounted) return;
    currentRecipe = ModalRoute.of(context)!.settings.arguments as Recipe;
    _titleController.text = currentRecipe.title;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _updateRecipe({
    String? title,
    String? description,
    List<String>? ingredients,
    List<String>? instructions,
    String? cookingTime,
    String? servings,
    List<String>? tags,
  }) {
    setState(() {
      currentRecipe = Recipe(
        id: currentRecipe.id,
        title: title ?? currentRecipe.title,
        ingredients: ingredients ?? currentRecipe.ingredients,
        instructions: instructions ?? currentRecipe.instructions,
        description: description ?? currentRecipe.description,
        imageUrl: currentRecipe.imageUrl,
        cookingTime: cookingTime ?? currentRecipe.cookingTime,
        difficulty: currentRecipe.difficulty,
        servings: servings ?? currentRecipe.servings,
        source: currentRecipe.source,
        tags: tags ?? currentRecipe.tags,
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
                  Card(
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 250,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                currentRecipe.imageUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child:
                                    _isEditingTitle
                                        ? TextFormField(
                                          controller: _titleController,

                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.titleLarge,
                                          autofocus: true,
                                          onFieldSubmitted: (value) {
                                            setState(() {
                                              _isEditingTitle = false;
                                              _updateRecipe(title: value);
                                            });
                                          },
                                        )
                                        : Text(
                                          currentRecipe.title,
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.titleLarge,
                                        ),
                              ),
                              IconButton(
                                icon: Icon(
                                  _isEditingTitle
                                      ? Icons.check
                                      : Icons.edit_note_outlined,
                                ),
                                onPressed: () {
                                  if (_isEditingTitle) {
                                    setState(() {
                                      _isEditingTitle = false;
                                      _updateRecipe(
                                        title: _titleController.text,
                                      );
                                    });
                                  } else {
                                    setState(() {
                                      _isEditingTitle = true;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          Text('Shared from ${currentRecipe.source}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Description
                  EditableRecipeField(
                    label: 'Description',
                    value: currentRecipe.description,
                    hintText: 'Enter recipe description',
                    isMultiline: true,
                    onSave: (value) => _updateRecipe(description: value),
                  ),
                  const SizedBox(height: 15),

                  // Ingredients
                  EditableRecipeField(
                    label: 'Ingredients',
                    value: currentRecipe.ingredients.join('\n'),
                    hintText: 'Enter ingredients (one per line)',
                    isMultiline: true,
                    onSave:
                        (value) => _updateRecipe(
                          ingredients:
                              value
                                  .split('\n')
                                  .map((e) => e.trim())
                                  .where((e) => e.isNotEmpty)
                                  .toList(),
                        ),
                    customDisplay: Text(currentRecipe.ingredients.join(', ')),
                  ),
                  const SizedBox(height: 15),

                  // Instructions
                  EditableRecipeField(
                    label: 'Instructions',
                    value: currentRecipe.instructions.join('\n'),
                    hintText: 'Enter instructions (one per line)',
                    isMultiline: true,
                    onSave:
                        (value) => _updateRecipe(
                          instructions:
                              value
                                  .split('\n')
                                  .map((e) => e.trim())
                                  .where((e) => e.isNotEmpty)
                                  .toList(),
                        ),
                    customDisplay: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(
                        currentRecipe.instructions.length,
                        (index) => Text(
                          '${index + 1}. ${currentRecipe.instructions[index]}',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Cooking Details
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap:
                              () => _updateRecipe(
                                cookingTime: currentRecipe.cookingTime,
                              ),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                'Cooking Time: ${currentRecipe.cookingTime} minutes',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap:
                              () => _updateRecipe(
                                servings: currentRecipe.servings,
                              ),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                'Servings: ${currentRecipe.servings}',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // Tags
                  RecipeTags(
                    tags: currentRecipe.tags,
                    onAddTag: (tag) {
                      if (!currentRecipe.tags.contains(tag)) {
                        _updateRecipe(tags: [...currentRecipe.tags, tag]);
                      }
                    },
                    onDeleteTag: (index) {
                      final newTags = List<String>.from(currentRecipe.tags)
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
                        onPressed: () => _autoFillRecipe(currentRecipe),
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
                        onPressed: () => _saveRecipe(currentRecipe),
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
