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
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      Recipe recipe = await ApiService.generateAIRecipe(
        ingredients: _ingredientsController.text,
        dietaryRestrictions: _dietController.text,
        cuisineType: _cuisineController.text,
      );
      setState(() {
        _generatedRecipe = recipe;
        _isLoading = false;
      });
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
                              ),
                              validator:
                                  (value) =>
                                      value == null || value.isEmpty
                                          ? 'Enter ingredients'
                                          : null,
                            ),
                            TextFormField(
                              controller: _dietController,
                              decoration: InputDecoration(
                                labelText: 'Dietary Restrictions',
                              ),
                            ),
                            TextFormField(
                              controller: _cuisineController,
                              decoration: InputDecoration(
                                labelText: 'Cuisine Type',
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
