import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recipe.dart';
import 'dart:io'; // Import the dart:io library
import 'package:logger/logger.dart'; // Import the logger package

class ApiService {
  static final Logger logger = Logger(); // Create a logger instance

  // Change the baseUrl based on the environment
  static String get baseUrl {
    // Check for production environment
    const bool isProduction = bool.fromEnvironment('dart.vm.product');

    if (isProduction) {
      return 'https://your-production-server.com'; // Use this for production
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000'; // Use this for Android emulator
    } else {
      return 'http://localhost:3000'; // Use this for other environments (e.g., iOS, web)
    }
  }

  static Future<List<Recipe>> fetchRecipes() async {
    final response = await http.get(Uri.parse('$baseUrl/recipes'));
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      logger.i(data); // Use logger instead of print
      return data.map((json) => Recipe.fromJson(json)).toList();
    } else {
      logger.e('Failed to load recipes: ${response.statusCode}'); // Log error
      throw Exception('Failed to load recipes');
    }
  }

  static Future<Recipe> createRecipe(Recipe recipe) async {
    final response = await http.post(
      Uri.parse('$baseUrl/recipes'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(recipe.toJson()),
    );

    if (response.statusCode == 201) {
      return Recipe.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create recipe');
    }
  }

  static Future<Recipe> updateRecipe(Recipe recipe) async {
    final response = await http.put(
      Uri.parse('$baseUrl/recipes/${recipe.id}'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(recipe.toJson()),
    );
    if (response.statusCode == 200) {
      return Recipe.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update recipe');
    }
  }

  static Future<void> deleteRecipe(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/recipes/$id'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete recipe');
    }
  }

  static Future<Recipe> generateAIRecipe({
    String? ingredients,
    String? dietaryRestrictions,
    String? cuisineType,
    String? cookingTime,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/recipes/generate'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'ingredients': ingredients,
        'dietaryRestrictions': dietaryRestrictions,
        'cuisineType': cuisineType,
        'cookingTime': cookingTime,
      }),
    );
    if (response.statusCode == 200) {
      return Recipe.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to generate recipe');
    }
  }

  static Future<Recipe> importSocialRecipe(String url) async {
    final response = await http.post(
      Uri.parse('$baseUrl/recipes/import'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'url': url}),
    );
    if (response.statusCode == 200) {
      return Recipe.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to import recipe');
    }
  }

  static Future<Recipe> fillSocialRecipe(Recipe recipeDetails) async {
    final response = await http.post(
      Uri.parse('$baseUrl/recipes/fill'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'recipe': recipeDetails.toJson()}),
    );
    if (response.statusCode == 200) {
      return Recipe.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to fill recipe');
    }
  }
}
