import 'package:flutter/material.dart';
import 'recipe.dart';

class RecipeCollection {
  final String id;
  final String name;
  final List<Recipe> recipes;
  final Color color;
  final IconData icon;
  final DateTime createdAt;
  final DateTime updatedAt;

  RecipeCollection({
    required this.id,
    required this.name,
    this.recipes = const [],
    required this.color,
    required this.icon,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  // Create a default collection with a specific name
  factory RecipeCollection.withName(
    String name, {
    Color? color,
    IconData? icon,
  }) {
    return RecipeCollection(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      color: color ?? _getDefaultColor(name),
      icon: icon ?? _getDefaultIcon(name),
    );
  }

  // Convert from JSON
  factory RecipeCollection.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String;

    return RecipeCollection(
      id: json['id'],
      name: name,
      recipes:
          (json['recipes'] as List?)
              ?.map((recipeJson) => Recipe.fromJson(recipeJson))
              .toList() ??
          [],
      color:
          json['color'] != null
              ? Color(json['color'] as int)
              : _getDefaultColor(name),
      icon: _getDefaultIcon(name), // Always use predefined icons
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'recipes': recipes.map((recipe) => recipe.toJson()).toList(),
    'color': color.toARGB32(),
    // Icon is always determined by name, so no need to store icon data
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  // Add a recipe to this collection
  RecipeCollection addRecipe(Recipe recipe) {
    final updatedRecipes = List<Recipe>.from(recipes);
    if (!updatedRecipes.any((r) => r.id == recipe.id)) {
      updatedRecipes.add(recipe);
    }

    return RecipeCollection(
      id: id,
      name: name,
      recipes: updatedRecipes,
      color: color,
      icon: icon,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // Remove a recipe from this collection
  RecipeCollection removeRecipe(String recipeId) {
    return RecipeCollection(
      id: id,
      name: name,
      recipes: recipes.where((recipe) => recipe.id != recipeId).toList(),
      color: color,
      icon: icon,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // Helper to get default icon based on category name
  static IconData _getDefaultIcon(String category) {
    final Map<String, IconData> categoryIcons = {
      'Breakfast': Icons.free_breakfast,
      'Lunch': Icons.lunch_dining,
      'Dinner': Icons.dinner_dining,
      'Snacks': Icons.cookie,
      'Drinks': Icons.local_bar,
      'Baked Goods': Icons.bakery_dining,
      'Appetizers': Icons.kebab_dining,
      'Desserts': Icons.cake,
      'Vegetarian': Icons.spa,
      'Vegan': Icons.cruelty_free,
      'Gluten-Free': Icons.not_interested,
      'Dairy-Free': Icons.format_color_reset,
      'Quick Meals': Icons.ramen_dining,
      'Holiday Specials': Icons.celebration,
      'Favorites': Icons.favorite,
      'Recently Added': Icons.schedule,
      // Cuisines
      'Italian': Icons.local_pizza,
      'Mexican': Icons.whatshot,
      'Chinese': Icons.ramen_dining,
      'Japanese': Icons.set_meal,
      'Indian': Icons.local_fire_department,
      'Thai': Icons.restaurant_menu_rounded,
      'French': Icons.wine_bar,
      'American': Icons.lunch_dining,
      'Mediterranean': Icons.local_florist,
      'Korean': Icons.ramen_dining,
      'Greek': Icons.local_florist,
      'Spanish': Icons.tapas,
      'British': Icons.local_cafe,
      'German': Icons.sports_bar,
      'Turkish': Icons.kebab_dining,
    };

    // Check if category name contains any of the key values (case-insensitive)
    final lowerCaseCategory = category.toLowerCase();
    for (final entry in categoryIcons.entries) {
      if (lowerCaseCategory.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }

    return Icons.restaurant;
  }

  // Helper to get default color based on category name
  static Color _getDefaultColor(String category) {
    final Map<String, Color> categoryColors = {
      'Breakfast': Colors.amber.shade500,
      'Lunch': Colors.green.shade200,
      'Dinner': Colors.indigo.shade200,
      'Snacks': Colors.orange.shade200,
      'Desserts': Colors.pink.shade200,
      'Baked Goods': Colors.brown.shade200,
      'Appetizers': Colors.teal.shade200,
      'Vegetarian': Colors.teal.shade200,
      'Vegan': Colors.lightGreen.shade200,
      'Gluten-Free': Colors.purple.shade200,
      'Dairy-Free': Colors.blue.shade200,
      'Quick Meals': Colors.red.shade200,
      'Holiday Specials': Colors.deepPurple.shade200,
      'Favorites': Colors.red.shade200,
      'Recently Added': Colors.cyan.shade200,
      // Cuisines
      'Italian': Colors.green.shade300,
      'Mexican': Colors.orange.shade300,
      'Chinese': Colors.red.shade300,
      'Japanese': Colors.pink.shade300,
      'Indian': Colors.deepOrange.shade300,
      'Thai': Colors.lime.shade300,
      'French': Colors.indigo.shade300,
      'American': Colors.blue.shade300,
      'Mediterranean': Colors.lightBlue.shade300,
      'Korean': Colors.purple.shade300,
      'Greek': Colors.cyan.shade300,
      'Spanish': Colors.amber.shade300,
      'British': Colors.brown.shade300,
      'German': Colors.grey.shade400,
      'Turkish': Colors.teal.shade300,
    };

    // Check if category name contains any of the key values (case-insensitive)
    final lowerCaseCategory = category.toLowerCase();
    for (final entry in categoryColors.entries) {
      if (lowerCaseCategory.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }

    return Colors.grey.shade200;
  }

  // Create a copy of this collection with updated fields
  RecipeCollection copyWith({
    String? name,
    List<Recipe>? recipes,
    Color? color,
  }) {
    return RecipeCollection(
      id: id,
      name: name ?? this.name,
      recipes: recipes ?? this.recipes,
      color: color ?? this.color,
      icon: _getDefaultIcon(
        name ?? this.name,
      ), // Always use predefined icon based on name
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
