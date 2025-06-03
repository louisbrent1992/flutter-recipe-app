import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipease/components/custom_app_bar.dart';
import 'package:recipease/providers/recipe_provider.dart';
import 'package:recipease/components/checkbox_list.dart';
import 'package:recipease/components/screen_description_card.dart';
import 'package:recipease/components/floating_home_button.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:recipease/theme/theme.dart';
import '../components/error_display.dart';

class GenerateRecipeScreen extends StatefulWidget {
  const GenerateRecipeScreen({super.key});

  @override
  GenerateRecipeScreenState createState() => GenerateRecipeScreenState();
}

class GenerateRecipeScreenState extends State<GenerateRecipeScreen> {
  final TextEditingController _ingredientController = TextEditingController();
  final List<String> _ingredients = [];
  final List<String> _dietaryRestrictions = [];
  String _cuisineType = 'American';
  double _cookingTime = 30;
  final ScrollController _scrollController = ScrollController();

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

  void _handleDietaryPreferences(List<String> preferences) {
    setState(() {
      _dietaryRestrictions.clear();
      _dietaryRestrictions.addAll(preferences);
    });
  }

  void _loadRecipes(BuildContext context) async {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);

    try {
      // Show loading indicator
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Generating Recipes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(),
                  ],
                ),
              ),
        );
      }

      await recipeProvider.generateRecipes(
        ingredients: _ingredients,
        dietaryRestrictions: _dietaryRestrictions,
        cuisineType: _cuisineType,
      );

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (context.mounted && recipeProvider.generatedRecipes.isNotEmpty) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipes generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to generated recipes screen
        Navigator.pushNamed(context, '/generatedRecipes');
      } else if (context.mounted) {
        // Show error message if no recipes were generated
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No recipes were generated. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if it's still showing
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (context.mounted) {
        showDialog(
          context: context,
          builder:
              (context) => ErrorDisplay(
                message:
                    e.toString().contains('Connection error')
                        ? 'Unable to connect to server. Please check your internet connection.'
                        : 'Error generating recipes: ${e.toString()}',
                isNetworkError:
                    e.toString().toLowerCase().contains('connection') ||
                    e.toString().toLowerCase().contains('network'),
                isAuthError:
                    e.toString().toLowerCase().contains('auth') ||
                    e.toString().toLowerCase().contains('login'),
                isFormatError:
                    e.toString().toLowerCase().contains('format') ||
                    e.toString().toLowerCase().contains('parse'),
                onRetry: () {
                  Navigator.pop(context);
                  _loadRecipes(context);
                },
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
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Generate Recipe',
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                expandedHeight: 200,
                automaticallyImplyLeading: false,
                flexibleSpace: CachedNetworkImage(
                  imageUrl:
                      'https://images.unsplash.com/photo-1504674900247-0877df9cc836?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Mnx8cmVjaXBlJTIwZ2VuZXJhdGlvbnxlbnwwfHwwfHx8MA%3D%3D&w=1000&q=80',
                  fit: BoxFit.cover,
                  placeholder:
                      (context, url) =>
                          const Center(child: CircularProgressIndicator()),
                  errorWidget:
                      (context, url, error) =>
                          const Icon(Icons.error, color: Colors.red),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: AppSpacing.allResponsive(context),
                  child: Consumer<RecipeProvider>(
                    builder: (context, recipeProvider, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ScreenDescriptionCard(
                            title: 'AI Recipe Generator',
                            description:
                                'Enter your ingredients, dietary preferences, and cooking time to generate personalized recipes.',
                          ),
                          SizedBox(height: AppSpacing.responsive(context)),
                          Text(
                            'Ingredients:',
                            style: Theme.of(
                              context,
                            ).textTheme.headlineSmall?.copyWith(
                              fontSize: AppTypography.responsiveHeadingSize(
                                context,
                                mobile: 18,
                                tablet: 20,
                                desktop: 22,
                              ),
                            ),
                          ),
                          SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: _ingredientController,
                            style: TextStyle(
                              fontSize: AppTypography.responsiveFontSize(
                                context,
                              ),
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  'Enter any ingredients or preferences you have (e.g. gluten-free, vegan, eggs etc.)',
                              hintStyle: TextStyle(
                                fontSize: AppTypography.responsiveCaptionSize(
                                  context,
                                ),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  Icons.add,
                                  size: AppSizing.responsiveIconSize(context),
                                ),
                                onPressed: _addIngredient,
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
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          DietaryPreferenceCheckboxList(
                            label: 'Select Preferences',
                            selectedPreferences: _dietaryRestrictions,
                            onChanged: _handleDietaryPreferences,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Cuisine Type:',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              16.0,
                              0,
                              16.0,
                              0,
                            ),
                            child: DropdownButton<String>(
                              value: _cuisineType,
                              onChanged: (String? newValue) {
                                setState(() {
                                  _cuisineType = newValue!;
                                });
                              },
                              items:
                                  <String>[
                                    'American',
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
                                    'Brazilian',
                                    'Dutch',
                                    'Belgian',
                                    'Swedish',
                                    'Norwegian',
                                    'Danish',
                                  ].map<DropdownMenuItem<String>>((
                                    String value,
                                  ) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(
                                        value,
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                      ),
                                    );
                                  }).toList(),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Cooking Time:',
                            style: Theme.of(context).textTheme.headlineSmall,
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
                          const SizedBox(height: 24),
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
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const FloatingHomeButton(),
        ],
      ),
    );
  }
}
