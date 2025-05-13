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
    return RecipeCollection(
      id: json['id'],
      name: json['name'],
      recipes:
          (json['recipes'] as List?)
              ?.map((recipeJson) => Recipe.fromJson(recipeJson))
              .toList() ??
          [],
      color:
          json['color'] != null
              ? Color(json['color'] as int)
              : _getDefaultColor(json['name'] as String),
      icon: _createIconData(
        json['iconCodePoint'] as int? ?? 0xe318, // Default to restaurant icon
        json['iconFontFamily'] as String?,
        json['iconFontPackage'] as String?,
      ),
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
    'iconCodePoint': icon.codePoint,
    'iconFontFamily': icon.fontFamily,
    'iconFontPackage': icon.fontPackage,
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
      'Breakfast': Icons.breakfast_dining,
      'Lunch': Icons.lunch_dining,
      'Dinner': Icons.dinner_dining,
      'Snacks': Icons.cookie,
      'Desserts': Icons.cake,
      'Vegetarian': Icons.spa,
      'Vegan': Icons.grass,
      'Gluten-Free': Icons.not_interested,
      'Dairy-Free': Icons.no_drinks,
      'Quick Meals': Icons.timer,
      'Holiday Specials': Icons.celebration,
      'Favorites': Icons.favorite,
      'Recently Added': Icons.new_releases,
    };

    return categoryIcons[category] ?? Icons.restaurant;
  }

  // Helper to get default color based on category name
  static Color _getDefaultColor(String category) {
    final Map<String, Color> categoryColors = {
      'Breakfast': Colors.amber.shade200,
      'Lunch': Colors.green.shade200,
      'Dinner': Colors.indigo.shade200,
      'Snacks': Colors.orange.shade200,
      'Desserts': Colors.pink.shade200,
      'Vegetarian': Colors.teal.shade200,
      'Vegan': Colors.lightGreen.shade200,
      'Gluten-Free': Colors.purple.shade200,
      'Dairy-Free': Colors.blue.shade200,
      'Quick Meals': Colors.red.shade200,
      'Holiday Specials': Colors.deepPurple.shade200,
      'Favorites': Colors.red.shade200,
      'Recently Added': Colors.cyan.shade200,
    };

    return categoryColors[category] ?? Colors.grey.shade200;
  }

  // Create a copy of this collection with updated fields
  RecipeCollection copyWith({
    String? name,
    List<Recipe>? recipes,
    Color? color,
    IconData? icon,
  }) {
    return RecipeCollection(
      id: id,
      name: name ?? this.name,
      recipes: recipes ?? this.recipes,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // Add this static method inside the RecipeCollection class
  // Place it near the other static helper methods (around line 120)
  static IconData _createIconData(
    int codePoint,
    String? fontFamily,
    String? fontPackage,
  ) {
    if (fontFamily == 'MaterialIcons') {
      // Check common Material icon code points
      switch (codePoint) {
        case 0xe318:
          return Icons.restaurant;
        case 0xe42e:
          return Icons.breakfast_dining;
        case 0xe1fc:
          return Icons.lunch_dining;
        case 0xe153:
          return Icons.dinner_dining;
        case 0xe11b:
          return Icons.cookie;
        case 0xe08d:
          return Icons.cake;
        case 0xe576:
          return Icons.spa;
        case 0xe2bf:
          return Icons.grass;
        case 0xead7:
          return Icons.not_interested;
        case 0xe381:
          return Icons.no_drinks;
        case 0xe425:
          return Icons.timer;
        case 0xe0c8:
          return Icons.celebration;
        case 0xe25b:
          return Icons.favorite;
        case 0xe05b:
          return Icons.new_releases;
        default:
          // Return a default icon when code point is not recognized
          return Icons.restaurant;
      }
    } else {
      // Handle unknown font families with a default icon
      return Icons.restaurant;
    }
  }
}
