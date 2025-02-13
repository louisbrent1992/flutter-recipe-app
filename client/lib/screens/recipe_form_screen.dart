import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';

class RecipeFormScreen extends StatefulWidget {
  final Recipe? recipe;
  const RecipeFormScreen({super.key, this.recipe});

  @override
  _RecipeFormScreenState createState() => _RecipeFormScreenState();
}

class _RecipeFormScreenState extends State<RecipeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _ingredientsController;
  late TextEditingController _stepsController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.recipe?.title ?? '');
    _ingredientsController = TextEditingController(
      text: widget.recipe?.ingredients.join(", ") ?? '',
    );
    _stepsController = TextEditingController(
      text: widget.recipe?.steps.join(", ") ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.recipe?.description ?? '',
    );
  }

  void _saveRecipe() async {
    if (_formKey.currentState!.validate()) {
      Recipe newRecipe = Recipe(
        id: widget.recipe?.id,
        title: _titleController.text,
        ingredients:
            _ingredientsController.text
                .split(',')
                .map((e) => e.trim())
                .toList(),
        steps: _stepsController.text.split(',').map((e) => e.trim()).toList(),
        description: _descriptionController.text,
      );
      if (widget.recipe == null) {
        await ApiService.createRecipe(newRecipe);
      } else {
        await ApiService.updateRecipe(newRecipe);
      }
      Navigator.pop(context);
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(labelText: 'Recipe Title'),
                validator:
                    (value) =>
                        value == null || value.isEmpty ? 'Enter title' : null,
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Description'),
              ),
              TextFormField(
                controller: _ingredientsController,
                decoration: InputDecoration(
                  labelText: 'Ingredients (comma separated)',
                ),
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Enter ingredients'
                            : null,
              ),
              TextFormField(
                controller: _stepsController,
                decoration: InputDecoration(
                  labelText: 'Steps (comma separated)',
                ),
                validator:
                    (value) =>
                        value == null || value.isEmpty ? 'Enter steps' : null,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveRecipe,
                child: Text('Save Recipe'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
