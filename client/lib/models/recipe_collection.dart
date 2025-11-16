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
  // Uses keyword matching with grouped keywords for efficient icon assignment
  static IconData _getDefaultIcon(String category) {
    final lowerCaseCategory = category.toLowerCase().trim();

    // Define icon mappings with keyword groups (ordered by priority)
    // Each entry maps a list of keywords to an icon
    // First match wins, so order matters for priority
    final List<MapEntry<List<String>, IconData>> iconMappings = [
      // Meal times (highest priority)
      MapEntry(['breakfast', 'morning', 'brunch'], Icons.free_breakfast),
      MapEntry(['lunch', 'midday'], Icons.lunch_dining),
      MapEntry(['dinner', 'evening', 'supper'], Icons.dinner_dining),

      // Sweets & snacks (grouped keywords)
      MapEntry([
        'sweet',
        'sweets',
        'snack',
        'snacks',
        'candy',
        'candies',
        'treat',
        'treats',
      ], Icons.cookie),

      // Soups (handles singular and plural)
      MapEntry([
        'soup',
        'soups',
        'stew',
        'stews',
        'broth',
        'broths',
      ], Icons.soup_kitchen),

      // Desserts
      MapEntry([
        'dessert',
        'desserts',
        'cake',
        'cakes',
        'pie',
        'pies',
        'pudding',
      ], Icons.cake),

      // Baked goods
      MapEntry([
        'baked',
        'baking',
        'bread',
        'breads',
        'muffin',
        'muffins',
        'biscuit',
        'biscuits',
      ], Icons.bakery_dining),

      // Drinks & beverages
      MapEntry([
        'drink',
        'drinks',
        'beverage',
        'beverages',
        'juice',
        'smoothie',
        'smoothies',
      ], Icons.local_bar),

      // Appetizers & starters
      MapEntry([
        'appetizer',
        'appetizers',
        'starter',
        'starters',
        'hors d\'oeuvre',
      ], Icons.kebab_dining),

      // Dietary restrictions
      MapEntry(['vegetarian', 'veggie'], Icons.spa),
      MapEntry(['vegan'], Icons.cruelty_free),
      MapEntry(['gluten', 'gluten-free', 'gluten free'], Icons.not_interested),
      MapEntry([
        'dairy',
        'dairy-free',
        'dairy free',
        'lactose',
      ], Icons.format_color_reset),

      // Quick meals
      MapEntry([
        'quick',
        'fast',
        'easy',
        'simple',
        '30 minute',
        '15 minute',
      ], Icons.ramen_dining),

      // Special occasions
      MapEntry([
        'holiday',
        'holidays',
        'christmas',
        'thanksgiving',
        'easter',
        'celebration',
      ], Icons.celebration),
      MapEntry([
        'favorite',
        'favourites',
        'favorites',
        'starred',
        'bookmarked',
      ], Icons.favorite),
      MapEntry(['recent', 'recently', 'new', 'latest'], Icons.schedule),

      // Cuisines (ordered by commonality)
      MapEntry([
        'italian',
        'italy',
        'pasta',
        'pizza',
        'risotto',
      ], Icons.local_pizza),
      MapEntry([
        'mexican',
        'mexico',
        'taco',
        'tacos',
        'burrito',
        'enchilada',
      ], Icons.whatshot),
      MapEntry([
        'chinese',
        'china',
        'szechuan',
        'cantonese',
      ], Icons.ramen_dining),
      MapEntry([
        'japanese',
        'japan',
        'sushi',
        'ramen',
        'teriyaki',
      ], Icons.set_meal),
      MapEntry([
        'indian',
        'india',
        'curry',
        'curries',
        'tandoori',
        'masala',
      ], Icons.local_fire_department),
      MapEntry([
        'thai',
        'thailand',
        'pad thai',
        'tom yum',
      ], Icons.restaurant_menu_rounded),
      MapEntry(['french', 'france', 'bistro', 'ratatouille'], Icons.wine_bar),
      MapEntry([
        'american',
        'usa',
        'bbq',
        'barbecue',
        'burger',
        'burgers',
      ], Icons.lunch_dining),
      MapEntry([
        'mediterranean',
        'mediterranean',
        'hummus',
        'falafel',
      ], Icons.local_florist),
      MapEntry(['korean', 'korea', 'kimchi', 'bulgogi'], Icons.ramen_dining),
      MapEntry(['greek', 'greece', 'gyro', 'tzatziki'], Icons.local_florist),
      MapEntry(['spanish', 'spain', 'paella', 'tapas'], Icons.tapas),
      MapEntry([
        'british',
        'britain',
        'uk',
        'fish and chips',
      ], Icons.local_cafe),
      MapEntry([
        'german',
        'germany',
        'schnitzel',
        'bratwurst',
      ], Icons.sports_bar),
      MapEntry(['turkish', 'turkey', 'kebab', 'kebabs'], Icons.kebab_dining),
    ];

    // Check each mapping group (in priority order)
    for (final mapping in iconMappings) {
      final keywords = mapping.key;
      // Check if any keyword in the group matches (as a word, not just substring)
      for (final keyword in keywords) {
        // Use word boundary matching: check if keyword appears as a whole word
        // Handles both singular and plural: "soup" matches "soups" and "soup recipes"
        // Pattern: word boundary + keyword + optional 's' + word boundary
        // OR: word boundary + keyword (without trailing s) + word boundary
        final escapedKeyword = RegExp.escape(keyword);
        final regex = RegExp(
          r'\b' + escapedKeyword + r'(s)?\b',
          caseSensitive: false,
        );
        if (regex.hasMatch(lowerCaseCategory)) {
          return mapping.value;
        }
      }
    }

    // Default icon if no match found
    return Icons.restaurant;
  }

  // Helper to get default color based on category name
  // Uses keyword matching similar to icon matching for consistency
  static Color _getDefaultColor(String category) {
    final lowerCaseCategory = category.toLowerCase().trim();

    // Define color mappings with keyword groups (ordered by priority)
    final List<MapEntry<List<String>, Color>> colorMappings = [
      // Meal times
      MapEntry(['breakfast', 'morning', 'brunch'], Colors.amber.shade500),
      MapEntry(['lunch', 'midday'], Colors.green.shade200),
      MapEntry(['dinner', 'evening', 'supper'], Colors.indigo.shade200),

      // Sweets & snacks (grouped)
      MapEntry([
        'sweet',
        'sweets',
        'snack',
        'snacks',
        'candy',
        'candies',
        'treat',
        'treats',
      ], Colors.orange.shade200),

      // Desserts
      MapEntry([
        'dessert',
        'desserts',
        'cake',
        'cakes',
        'pie',
        'pies',
        'pudding',
      ], Colors.pink.shade200),

      // Baked goods
      MapEntry([
        'baked',
        'baking',
        'bread',
        'breads',
        'muffin',
        'muffins',
        'biscuit',
        'biscuits',
      ], Colors.brown.shade200),

      // Soups
      MapEntry([
        'soup',
        'soups',
        'stew',
        'stews',
        'broth',
        'broths',
      ], Colors.blue.shade200),

      // Appetizers
      MapEntry([
        'appetizer',
        'appetizers',
        'starter',
        'starters',
        'hors d\'oeuvre',
      ], Colors.teal.shade200),

      // Dietary restrictions
      MapEntry(['vegetarian', 'veggie'], Colors.teal.shade200),
      MapEntry(['vegan'], Colors.lightGreen.shade200),
      MapEntry([
        'gluten',
        'gluten-free',
        'gluten free',
      ], Colors.purple.shade200),
      MapEntry([
        'dairy',
        'dairy-free',
        'dairy free',
        'lactose',
      ], Colors.blue.shade200),

      // Quick meals
      MapEntry([
        'quick',
        'fast',
        'easy',
        'simple',
        '30 minute',
        '15 minute',
      ], Colors.red.shade200),

      // Special occasions
      MapEntry([
        'holiday',
        'holidays',
        'christmas',
        'thanksgiving',
        'easter',
        'celebration',
      ], Colors.deepPurple.shade200),
      MapEntry([
        'favorite',
        'favourites',
        'favorites',
        'starred',
        'bookmarked',
      ], Colors.red.shade200),
      MapEntry(['recent', 'recently', 'new', 'latest'], Colors.cyan.shade200),

      // Cuisines
      MapEntry([
        'italian',
        'italy',
        'pasta',
        'pizza',
        'risotto',
      ], Colors.green.shade300),
      MapEntry([
        'mexican',
        'mexico',
        'taco',
        'tacos',
        'burrito',
        'enchilada',
      ], Colors.orange.shade300),
      MapEntry([
        'chinese',
        'china',
        'szechuan',
        'cantonese',
      ], Colors.red.shade300),
      MapEntry([
        'japanese',
        'japan',
        'sushi',
        'ramen',
        'teriyaki',
      ], Colors.pink.shade300),
      MapEntry([
        'indian',
        'india',
        'curry',
        'curries',
        'tandoori',
        'masala',
      ], Colors.deepOrange.shade300),
      MapEntry([
        'thai',
        'thailand',
        'pad thai',
        'tom yum',
      ], Colors.lime.shade300),
      MapEntry([
        'french',
        'france',
        'bistro',
        'ratatouille',
      ], Colors.indigo.shade300),
      MapEntry([
        'american',
        'usa',
        'bbq',
        'barbecue',
        'burger',
        'burgers',
      ], Colors.blue.shade300),
      MapEntry([
        'mediterranean',
        'hummus',
        'falafel',
      ], Colors.lightBlue.shade300),
      MapEntry([
        'korean',
        'korea',
        'kimchi',
        'bulgogi',
      ], Colors.purple.shade300),
      MapEntry(['greek', 'greece', 'gyro', 'tzatziki'], Colors.cyan.shade300),
      MapEntry(['spanish', 'spain', 'paella', 'tapas'], Colors.amber.shade300),
      MapEntry([
        'british',
        'britain',
        'uk',
        'fish and chips',
      ], Colors.brown.shade300),
      MapEntry([
        'german',
        'germany',
        'schnitzel',
        'bratwurst',
      ], Colors.grey.shade400),
      MapEntry(['turkish', 'turkey', 'kebab', 'kebabs'], Colors.teal.shade300),
    ];

    // Check each mapping group (in priority order)
    for (final mapping in colorMappings) {
      final keywords = mapping.key;
      for (final keyword in keywords) {
        final escapedKeyword = RegExp.escape(keyword);
        final regex = RegExp(
          r'\b' + escapedKeyword + r'(s)?\b',
          caseSensitive: false,
        );
        if (regex.hasMatch(lowerCaseCategory)) {
          return mapping.value;
        }
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
