import 'package:flutter/material.dart';
import 'package:recipease/components/app_bar.dart';
import 'package:recipease/components/nav_drawer.dart';
import 'package:recipease/models/recipe.dart';
import 'package:recipease/services/api_service.dart';

class ImportRecipeScreen extends StatefulWidget {
  const ImportRecipeScreen({super.key});

  @override
  State<ImportRecipeScreen> createState() => _ImportRecipeScreenState();
}

class _ImportRecipeScreenState extends State<ImportRecipeScreen> {
  void _importRecipe(String url) async {
    // import recipe function
    Recipe recipe = await ApiService.importSocialRecipe(url);
    // then navigate to import details
    if (mounted) {
      Navigator.pushNamed(context, '/importDetails', arguments: recipe);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Import Recipe'),
      drawer: const NavDrawer(),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                // Create a sample recipe for testing

                Navigator.pushNamed(context, '/importDetails');
              },
              child: const Text('Import New Recipe'),
            ),
            const SizedBox(height: 20),
            const Text('Or paste a recipe URL to import'),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Paste recipe URL here',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (url) {
                  // Handle URL submission

                  _importRecipe(url);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
