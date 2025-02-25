class Recipe {
  final String? id;
  final String title;
  final List<String> ingredients;
  final List<String> steps;
  final String description;
  final String imageUrl;
  final String cookingTime;
  final String? servings;

  Recipe({
    this.id = '101',
    this.title = 'Classic Tomato Spaghetti',
    this.ingredients = const [
      'Spaghetti',
      'Fresh tomatoes',
      'Olive oil',
      'Garlic',
      'Basil',
      'Salt',
      'Pepper',
    ],
    this.steps = const [
      'Boil spaghetti in salted water according to package instructions.',
      'Chop tomatoes and garlic.',
      'Heat olive oil in a pan, sauté garlic until golden.',
      'Add chopped tomatoes and cook until soft.',
      'Drain spaghetti and mix with the sauce.',
      'Garnish with basil and serve hot.',
    ],
    this.description =
        'A simple yet delicious classic tomato spaghetti recipe that brings out the freshness of tomatoes paired with the aroma of basil.',
    this.imageUrl =
        'https://images.unsplash.com/photo-1605888969139-42cca4308aa2?q=80&w=685&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
    this.cookingTime = '25 mins',
    this.servings = '2',
  });

  // Convert from JSON
  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'],
      title: json['title'],
      ingredients: List<String>.from(json['ingredients']),
      steps: List<String>.from(json['steps']),
      description: json['description'],
      imageUrl: json['imageUrl'],
      cookingTime: json['cookingTime'],
      servings: json['servings'],
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'ingredients': ingredients,
      'steps': steps,
      'description': description,
      'imageUrl': imageUrl,
      'cookingTime': cookingTime,
    };
  }
}
