import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/recipe.dart';

class AIRecipeScreen extends StatefulWidget {
  const AIRecipeScreen({super.key});

  @override
  AIRecipeScreenState createState() => AIRecipeScreenState();
}

class AIRecipeScreenState extends State<AIRecipeScreen> {
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

      if (mounted) {
        setState(() {
          _generatedRecipe = recipe;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate recipe: $e')),
        );
      }
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
      appBar: AppBar(title: const Text('Generate AI Recipe')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _ingredientsController,
                  decoration: const InputDecoration(labelText: 'Ingredients'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _dietController,
                  decoration: const InputDecoration(
                    labelText: 'Dietary Restrictions',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _cuisineController,
                  decoration: const InputDecoration(labelText: 'Cuisine Type'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _generateRecipe,
                  child: const Text('Generate Recipe'),
                ),
                if (_isLoading) ...[
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(),
                ],
                if (_generatedRecipe != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    _generatedRecipe!.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _generatedRecipe!.description,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Ingredients: ${_generatedRecipe!.ingredients.join(", ")}',
                  ),
                  const SizedBox(height: 10),
                  Text('Steps: ${_generatedRecipe!.steps.join(" -> ")}'),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
