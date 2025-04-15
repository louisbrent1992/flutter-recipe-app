import 'package:share_plus/share_plus.dart';

class Recipe {
  final String id;
  final String title;
  final List<String> ingredients;
  final List<String> instructions;
  final String description;
  final String imageUrl;
  final String cookingTime;
  final String difficulty;
  final String servings;
  final String? source;
  final List<String> tags;
  final DateTime createdAt;

  Recipe({
    this.id = '',
    this.title = 'Recipe Title',
    this.ingredients = const ['Ingredient 1', 'Ingredient 2', 'Ingredient 3'],
    this.instructions = const ['Step 1', 'Step 2', 'Step 3'],
    this.description =
        'A delightful recipe that combines the best of flavors and textures to create a memorable dish. Perfect for any occasion!',
    this.imageUrl =
        'https://images.unsplash.com/photo-1542010589005-d1eacc3918f2?q=80&w=2092&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
    this.cookingTime = '45',
    this.difficulty = 'Easy',
    this.servings = '4',
    this.source = 'Instagram',
    this.tags = const ['Breakfast', 'Lunch', 'Dinner', 'Snack', 'Dessert'],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert from JSON
  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'],
      title: json['title'],
      ingredients: json['ingredients']?.cast<String>(),
      instructions: json['instructions']?.cast<String>(),
      description: json['description'],
      imageUrl: json['imageUrl'],
      cookingTime: json['cookingTime'],
      difficulty: json['difficulty'],
      servings: json['servings'],
      source: json['source'],
      tags: json['tags']?.cast<String>(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'ingredients': ingredients,
    'instructions': instructions,
    'description': description,
    'imageUrl': imageUrl,
    'cookingTime': cookingTime,
    'difficulty': difficulty,
    'servings': servings,
    'source': source,
    'tags': tags,
    'createdAt': createdAt.toIso8601String(),
  };

  Future<void> share() async {
    final recipeText = '''
🍳 $title

$description

⏱️ Cooking Time: $cookingTime
👥 Servings: $servings
📊 Difficulty: $difficulty

🛒 Ingredients:
${ingredients.map((i) => '• $i').join('\n')}

📝 Instructions:
${instructions.map((i) => '${instructions.indexOf(i) + 1}. $i').join('\n')}

🏷️ Tags: ${tags.join(', ')}
${source != null ? '\nSource: $source' : ''}

Shared via recipease
''';

    await Share.share(recipeText, subject: title);
  }
}
