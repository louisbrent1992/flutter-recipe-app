import 'package:flutter/material.dart';
import 'package:recipease/components/app_bar.dart';
import 'package:recipease/components/checkbox_list.dart';
import 'package:recipease/components/recipe_card.dart';
import 'package:recipease/components/screen_description_card.dart';
import 'package:recipease/models/recipe.dart';
import 'package:recipease/services/api_service.dart';

class GenerateRecipeScreen extends StatefulWidget {
  const GenerateRecipeScreen({Key? key}) : super(key: key);

  @override
  GenerateRecipeScreenState createState() => GenerateRecipeScreenState();
}

class GenerateRecipeScreenState extends State<GenerateRecipeScreen> {
  final TextEditingController _ingredientController = TextEditingController();
  final List<String> _ingredients = [];
  String _cuisineType = 'Italian';
  double _cookingTime = 30;
  bool _isLoading = false;
  List<Recipe> _recipes = [];

  void _addIngredient() {
    if (_ingredientController.text.isNotEmpty) {
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
    setState(() {
      _ingredients.clear();
    });
  }

  void _loadRecipes() async {
    List<Recipe> recipes = await ApiService.fetchRecipes();
    setState(() {
      _recipes = recipes;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'AI Recipe Generator'),
      body: SafeArea(
        child: SingleChildScrollView(
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
                          icon: const Icon(Icons.playlist_remove_outlined),
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
                                color: Theme.of(context).colorScheme.secondary,
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
                  onPressed: _loadRecipes,
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(
                      Theme.of(context).colorScheme.primary,
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
                if (_recipes.isNotEmpty)
                  ListView.builder(
                    itemBuilder:
                        (context, index) => RecipeCard(recipe: _recipes[index]),
                    itemCount: _recipes.length,
                  ),

                if (_isLoading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
