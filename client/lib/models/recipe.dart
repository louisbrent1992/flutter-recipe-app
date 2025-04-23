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
  final String? sourcePlatform;
  final String? sourceUrl;
  final String? author;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isFavorite;
  final String? userId;
  final String? cuisineType;
  final InstagramData? instagram;

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
    this.source,
    this.sourcePlatform,
    this.sourceUrl,
    this.author,
    this.tags = const ['Breakfast', 'Lunch', 'Dinner', 'Snack', 'Dessert'],
    DateTime? createdAt,
    this.updatedAt,
    this.isFavorite = false,
    this.userId,
    this.cuisineType,
    this.instagram,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert from JSON
  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Untitled Recipe',
      ingredients:
          json['ingredients'] != null
              ? List<String>.from(json['ingredients'])
              : [],
      instructions:
          json['instructions'] != null
              ? List<String>.from(json['instructions'])
              : [],
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      cookingTime: json['cookingTime']?.toString() ?? '0',
      difficulty: json['difficulty'] ?? 'Medium',
      servings: json['servings']?.toString() ?? '0',
      source: json['source'],
      sourcePlatform: json['sourcePlatform'],
      sourceUrl: json['sourceUrl'],
      author: json['author'],
      tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
      createdAt:
          json['createdAt'] != null
              ? DateTime.parse(json['createdAt'] as String)
              : DateTime.now(),
      updatedAt:
          json['updatedAt'] != null
              ? DateTime.parse(json['updatedAt'] as String)
              : null,
      isFavorite: json['isFavorite'] ?? false,
      userId: json['userId'],
      cuisineType: json['cuisineType'],
      instagram:
          json['instagram'] != null
              ? InstagramData.fromJson(json['instagram'])
              : null,
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
    'sourcePlatform': sourcePlatform,
    'sourceUrl': sourceUrl,
    'author': author,
    'tags': tags,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'isFavorite': isFavorite,
    'userId': userId,
    'cuisineType': cuisineType,
    'instagram': instagram?.toJson(),
  };

  // Create a copy of the recipe with updated values
  Recipe copyWith({
    String? id,
    String? title,
    List<String>? ingredients,
    List<String>? instructions,
    String? description,
    String? imageUrl,
    String? cookingTime,
    String? difficulty,
    String? servings,
    String? source,
    String? sourcePlatform,
    String? sourceUrl,
    String? author,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isFavorite,
    String? userId,
    String? cuisineType,
    InstagramData? instagram,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      cookingTime: cookingTime ?? this.cookingTime,
      difficulty: difficulty ?? this.difficulty,
      servings: servings ?? this.servings,
      source: source ?? this.source,
      sourcePlatform: sourcePlatform ?? this.sourcePlatform,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      author: author ?? this.author,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      userId: userId ?? this.userId,
      cuisineType: cuisineType ?? this.cuisineType,
      instagram: instagram ?? this.instagram,
    );
  }

  Future<void> share() async {
    final recipeText = '''
🍳 $title

$description

⏱️ Cooking Time: $cookingTime
👥 Servings: $servings
📊 Difficulty: $difficulty
${cuisineType != null && cuisineType!.isNotEmpty ? '🌎 Cuisine: $cuisineType' : ''}

🛒 Ingredients:
${ingredients.map((i) => '• $i').join('\n')}

📝 Instructions:
${instructions.map((i) => '${instructions.indexOf(i) + 1}. $i').join('\n')}

🏷️ Tags: ${tags.join(', ')}
${source != null ? '\nSource: $source' : ''}
${author != null ? 'By: $author' : ''}

Shared via recipease
''';

    await Share.share(recipeText, subject: title);
  }
}

// Class to store Instagram specific data
class InstagramData {
  final String? shortcode;
  final String? username;

  InstagramData({this.shortcode, this.username});

  factory InstagramData.fromJson(Map<String, dynamic> json) {
    return InstagramData(
      shortcode: json['shortcode'],
      username: json['username'],
    );
  }

  Map<String, dynamic> toJson() => {
    'shortcode': shortcode,
    'username': username,
  };
}
