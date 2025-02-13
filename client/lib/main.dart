import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/ai_recipe_screen.dart';
import 'screens/recipe_list_screen.dart';
import 'screens/recipe_detail_screen.dart';
import 'screens/recipe_form_screen.dart';
import 'screens/social_import_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Recipe App',
      theme: ThemeData(primarySwatch: Colors.deepOrange),
      initialRoute: '/',
      routes: {
        '/': (context) => HomeScreen(),
        '/aiRecipe': (context) => AIRecipeScreen(),
        '/recipeList': (context) => RecipeListScreen(),
        '/recipeDetail': (context) => RecipeDetailScreen(),
        '/recipeForm': (context) => RecipeFormScreen(),
        '/socialImport': (context) => SocialImportScreen(),
      },
    );
  }
}
