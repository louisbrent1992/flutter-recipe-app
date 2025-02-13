class Recipe {
  final String? id;
  final String title;
  final List<String> ingredients;
  final List<String> steps;
  final String? description;

  Recipe({
    this.id,
    required this.title,
    required this.ingredients,
    required this.steps,
    this.description,
  });

  // Convert from JSON
  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'],
      title: json['title'],
      ingredients: List<String>.from(json['ingredients']),
      steps: List<String>.from(json['steps']),
      description: json['description'],
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
    };
  }
}
