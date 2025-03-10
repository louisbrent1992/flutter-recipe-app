import 'package:flutter/material.dart';
import 'package:recipease/misc/share_intent.dart';
import 'package:recipease/models/recipe.dart';
import 'package:recipease/screens/discover_recipes.dart';
import 'package:recipease/screens/favorite_recipes.dart';
import 'package:recipease/screens/generate_recipe_screen.dart';
import 'package:recipease/screens/home_screen.dart';
import 'package:recipease/screens/import_details_screen.dart';
import 'package:recipease/screens/recipe_detail_screen.dart';
import 'package:recipease/screens/settings_screen.dart';
import 'package:recipease/theme/theme.dart';
import 'components/bottom_nav_bar.dart'; // Import the BottomNavBar

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recipe App',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: appThemeData.colorScheme,
      ),
      debugShowCheckedModeBanner: false,

      home: const BottomNavBar(), // Use BottomNavBar as the home widget
      routes: {
        '/home': (context) => const HomeScreen(),
        '/generate': (context) => const GenerateRecipeScreen(),
        '/import': (context) => ImportDetailsScreen(recipe: Recipe()),
        '/favorite': (context) => const FavoriteRecipesScreen(),
        '/settings': (context) => const SettingsScreen(),

        // '/notifications': (context) => const NotificationsScreen(),
        '/recipe': (context) => const RecipeDetailScreen(recipe: null),
        '/discover': (context) => const DiscoverRecipesScreen(),
      },
    );
  }
}
