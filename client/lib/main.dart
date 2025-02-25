import 'package:flutter/material.dart';
import 'screens/ai_recipe_screen.dart';
import 'screens/recipe_list_screen.dart';
import 'screens/recipe_detail_screen.dart';
import 'screens/recipe_form_screen.dart';
import 'screens/social_import_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/login_screen.dart';
import 'screens/new_home_screen.dart';
import 'screens/recipe_search.dart';
import 'screens/discover_recipe.dart';
import 'screens/settings_screen.dart';
import 'models/recipe.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  /*************  ✨ Codeium Command ⭐  *************/
  /// Builds the main application widget.
  ///
  /// Returns a [MaterialApp] widget configured with the application's title,
  /// theme, and routes. The initial route is set to the landing screen. It
  /// includes multiple routes for different screens such as home, AI recipe,
  /// recipe list, recipe detail, and others.
  /// ****  0847eaad-f93c-48a5-8490-417a7812b8f2  ******
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Recipe App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orangeAccent),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LandingScreen(),
        '/home': (context) => const NewHomeScreen(),
        '/aiRecipe': (context) => const AIRecipeScreen(),
        '/recipeList': (context) => const RecipeListScreen(),
        '/recipeDetail': (context) {
          return RecipeDetailScreen(recipe: Recipe());
        },
        '/recipeForm': (context) => const RecipeFormScreen(),
        '/socialImport': (context) => const SocialImportScreen(),
        '/login': (context) => const LoginScreen(),
        '/newHome': (context) => const NewHomeScreen(),
        '/search': (context) => const RecipeSearchScreen(),
        '/recipeSearch': (context) => const RecipeSearchScreen(),
        '/discoverRecipe': (context) => const DiscoverRecipeScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
