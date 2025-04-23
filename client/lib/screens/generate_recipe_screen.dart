import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipease/providers/recipe_provider.dart';
import 'package:recipease/components/recipe_card.dart';
import 'package:recipease/models/recipe.dart';
import 'package:recipease/components/custom_app_bar.dart';
import 'package:recipease/components/checkbox_list.dart';
import 'package:recipease/components/screen_description_card.dart';

class GenerateRecipeScreen extends StatefulWidget {
  const GenerateRecipeScreen({super.key});

  @override
  GenerateRecipeScreenState createState() => GenerateRecipeScreenState();
}

class GenerateRecipeScreenState extends State<GenerateRecipeScreen> {
  final TextEditingController _ingredientController = TextEditingController();
  final List<String> _ingredients = [];
  final List<String> _dietaryRestrictions = [];
  String _cuisineType = 'Italian';
  double _cookingTime = 30;
  final Map<String, bool> _savedRecipes = {};

  void _addIngredient() {
    if (_ingredientController.text.isNotEmpty && mounted) {
      setState(() {
        _ingredients.addAll(
          _ingredientController.text
              .split(',')
              .map((ingredient) => ingredient.trim()),
        );
        _ingredientController.clear();
      });
    }
  }

  void _clearIngredients() {
    if (mounted) {
      setState(() {
        _ingredients.clear();
      });
    }
  }

  void _handleDietaryPreferences(String dietaryPreference) {
    setState(() {
      if (mounted) {
        if (_dietaryRestrictions.contains(dietaryPreference)) {
          _dietaryRestrictions.remove(dietaryPreference);
        } else {
          _dietaryRestrictions.add(dietaryPreference);
        }
      }
    });
  }

  void _loadRecipes(BuildContext context) async {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);

    try {
      await recipeProvider.generateRecipes(
        ingredients: _ingredients,
        dietaryRestrictions: _dietaryRestrictions,
        cuisineType: _cuisineType,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('Connection error')
                  ? 'Unable to connect to server. Please check your internet connection.'
                  : 'Error generating recipes: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: () {},
              textColor: Colors.white,
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleRecipeAction(Recipe recipe) async {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    final isCurrentlySaved = _savedRecipes[recipe.id] ?? false;

    if (isCurrentlySaved) {
      // Remove from collection
      setState(() {
        _savedRecipes[recipe.id] = false;
      });
      await recipeProvider.deleteUserRecipe(recipe.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipe removed from your collection'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      setState(() {
        _savedRecipes[recipe.id] = true;
      });
      // Save to collection
      await recipeProvider.saveGeneratedRecipe(recipe);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipe saved to your collection!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _ingredientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var scrollController = ScrollController();
    return Scaffold(
      appBar: const CustomAppBar(title: 'AI Recipe Generator'),

      body: SafeArea(
        child: Consumer<RecipeProvider>(
          builder: (context, recipeProvider, _) {
            return Scrollbar(
              thumbVisibility: true,
              thickness: 10,
              controller: scrollController, // Attach ScrollController here
              child: SingleChildScrollView(
                controller: scrollController, // Attach ScrollController here
                child: Container(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ScreenDescriptionCard(
                        title: 'AI Recipe Generator',
                        description:
                            'Welcome to the AI Recipe Generator! This tool allows you to create delicious recipes based on the ingredients you have on hand. Simply enter the ingredients you want to use, and our AI will generate three unique recipes for you to try. Whether you are looking for a quick meal or something more elaborate, our AI has got you covered. Get ready to discover new and exciting dishes tailored for you!',
                        imageUrl:
                            'https://images.unsplash.com/photo-1504674900247-0877df9cc836?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Mnx8cmVjaXBlJTIwZ2VuZXJhdGlvbnxlbnwwfHwwfHx8MA%3D%3D&w=1000&q=80',
                      ),
                      const Divider(color: Color.fromARGB(16, 0, 0, 0)),
                      Text(
                        'Ingredients:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),

                      TextField(
                        controller: _ingredientController,
                        decoration: InputDecoration(
                          labelText:
                              'Enter ingredients (e.g., eggs, flour, tomatoes)',
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,

                            children: [
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: _addIngredient,
                                tooltip: 'Add Ingredient',
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.playlist_remove_outlined,
                                ),
                                onPressed: _clearIngredients,
                                tooltip: 'Clear Ingredients',
                              ),
                            ],
                          ),
                        ),
                        onSubmitted: (value) => _addIngredient(),
                      ),
                      Wrap(
                        spacing: 8.0,
                        children:
                            _ingredients
                                .map(
                                  (ingredient) => Chip(
                                    label: Text(ingredient),
                                    backgroundColor: Colors.grey[350],
                                    onDeleted: () {
                                      setState(() {
                                        _ingredients.remove(ingredient);
                                      });
                                    },
                                  ),
                                )
                                .toList(),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Dietary Preferences:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      DietaryPreferenceCheckboxList(
                        label: 'Select Preferences',
                        value:
                            false, // Initial value, you might want to manage this state
                        onChanged: (bool? value) {
                          // Handle change
                          _handleDietaryPreferences(value.toString());
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Cuisine Type:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 0),
                        child: DropdownButton<String>(
                          value: _cuisineType,
                          onChanged: (String? newValue) {
                            setState(() {
                              _cuisineType = newValue!;
                            });
                          },
                          items:
                              <String>[
                                'Italian',
                                'Chinese',
                                'Mexican',
                                'Indian',
                                'Japanese',
                                'French',
                                'Spanish',
                                'Thai',
                                'Greek',
                                'Turkish',
                                'Vietnamese',
                                'Korean',
                                'German',
                                'Polish',
                                'Portuguese',
                                'Russian',
                              ].map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    value,
                                    style: TextStyle(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.secondary,
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Cooking Time:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      Slider.adaptive(
                        value: _cookingTime,
                        min: 0,
                        max: 120,
                        divisions: 12,
                        label: _cookingTime.round().toString(),
                        onChanged: (double value) {
                          setState(() {
                            _cookingTime = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed:
                            recipeProvider.isLoading
                                ? null
                                : () => _loadRecipes(context),
                        style: const ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll(
                            Colors.deepPurple,
                          ),
                        ),

                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_awesome_outlined,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Generate Recipes',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Display error if there is one
                      if (recipeProvider.error != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.red.shade100,
                          child: Text(
                            recipeProvider.error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),

                      if (recipeProvider.generatedRecipes.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Generated Recipes:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...recipeProvider.generatedRecipes.map(
                              (recipe) => RecipeCard(
                                recipe: recipe,
                                showSaveButton:
                                    !(_savedRecipes[recipe.id] ?? false),
                                showRemoveButton:
                                    _savedRecipes[recipe.id] ?? false,
                                onSave: () => _handleRecipeAction(recipe),
                                onRemove: () => _handleRecipeAction(recipe),
                              ),
                            ),
                          ],
                        ),

                      if (recipeProvider.isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
