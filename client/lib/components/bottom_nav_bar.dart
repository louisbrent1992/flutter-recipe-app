import 'package:flutter/material.dart';
import 'package:recipease/screens/generate_recipe_screen.dart';
import 'package:recipease/screens/import_details_screen.dart';
import '../screens/home_screen.dart';
import '../screens/favorite_recipes.dart';
import '../screens/settings_screen.dart';

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int _currentIndex = 0;

  /******  fbff4cf8-f165-44f0-a7e9-aa2153574d1d  *******/
  ///
  final List<Widget> _screens = [
    const HomeScreen(),
    const FavoriteRecipesScreen(),
    const GenerateRecipeScreen(),
    const ImportDetailsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      extendBody: true,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        backgroundColor: Theme.of(context).colorScheme.primary,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(
              _currentIndex == 0 ? Icons.home : Icons.home_outlined,
              color: Colors.white,
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon:
                _currentIndex == 1
                    ? Icon(Icons.favorite, color: Colors.red[900])
                    : const Icon(Icons.favorite_border, color: Colors.white),
            label: '',
          ),
          BottomNavigationBarItem(
            icon:
                _currentIndex == 2
                    ? Icon(
                      Icons.auto_awesome,
                      color: Colors.purple[900],
                    ) // Add icon for the GenerateRecipeScreen
                    : const Icon(
                      Icons.auto_awesome_outlined,
                      color: Colors.white,
                    ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon:
                _currentIndex == 3
                    ? Icon(
                      Icons.add_box,
                      color: Colors.green[900],
                    ) // Add icon for the GenerateRecipeScreen
                    : const Icon(Icons.add_box_outlined, color: Colors.white),
            label: '',
          ),
          BottomNavigationBarItem(
            icon:
                _currentIndex == 4
                    ? Icon(
                      Icons.settings,
                      color: Theme.of(context).colorScheme.secondary,
                    )
                    : const Icon(Icons.settings_outlined, color: Colors.white),
            label: '',
          ),
        ],
      ),
    );
  }
}
