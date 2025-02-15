import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/recipe.dart';

class AIRecipeScreen extends StatefulWidget {
  const AIRecipeScreen({super.key});

  @override
  _AIRecipeScreenState createState() => _AIRecipeScreenState();
}

class _AIRecipeScreenState extends State<AIRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _ingredientsController = TextEditingController();
  final TextEditingController _dietController = TextEditingController();
  final TextEditingController _cuisineController = TextEditingController();
  Recipe? _generatedRecipe;
  bool _isLoading = false;

  void _generateRecipe() async {
    setState(() {
      _isLoading = true;
    });

    // Get user inputs or use default values
    String? ingredients =
        _ingredientsController.text.isNotEmpty
            ? _ingredientsController.text
            : ""; // Default ingredients
    String? dietaryRestrictions =
        _dietController.text.isNotEmpty
            ? _dietController.text
            : null; // Default to null if not provided
    String? cuisineType =
        _cuisineController.text.isNotEmpty
            ? _cuisineController.text
            : null; // Default to null if not provided

    try {
      Recipe recipe = await ApiService.generateAIRecipe(
        ingredients: ingredients,
        dietaryRestrictions: dietaryRestrictions,
        cuisineType: cuisineType,
      );

      // Log the recipe object to the console
      print('Generated Recipe: ${recipe.toJson()}');

      setState(() {
        _generatedRecipe = recipe;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Handle error (e.g., show a snackbar or dialog)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to generate recipe: $e')));
    }
  }

  @override
  void dispose() {
    _ingredientsController.dispose();
    _dietController.dispose();
    _cuisineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Generate AI Recipe')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  child: Column(
                    children: [
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _ingredientsController,
                              decoration: InputDecoration(
                                labelText: 'Ingredients (comma separated)',
                                hintText:
                                    'Enter ingredients or leave blank for defaults',
                              ),
                            ),
                            TextFormField(
                              controller: _dietController,
                              decoration: InputDecoration(
                                labelText: 'Dietary Restrictions',
                                hintText:
                                    'Enter dietary restrictions or leave blank for defaults',
                              ),
                            ),
                            TextFormField(
                              controller: _cuisineController,
                              decoration: InputDecoration(
                                labelText: 'Cuisine Type',
                                hintText:
                                    'Enter cuisine type or leave blank for defaults',
                              ),
                            ),
                            SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _generateRecipe,
                              child: Text('Generate Recipe'),
                            ),
                          ],
                        ),
                      ),
                      if (_generatedRecipe != null) ...[
                        SizedBox(height: 20),
                        Text(
                          _generatedRecipe!.title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Ingredients: ${_generatedRecipe!.ingredients.join(", ")}',
                        ),
                        SizedBox(height: 10),
                        Text('Steps: ${_generatedRecipe!.steps.join(" -> ")}'),
                      ],
                    ],
                  ),
                ),
      ),
    );
  }
}
