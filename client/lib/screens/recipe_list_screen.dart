import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';

class RecipeListScreen extends StatefulWidget {
  const RecipeListScreen({super.key});

  @override
  _RecipeListScreenState createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  List<Recipe> _recipes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  void _loadRecipes() async {
    List<Recipe> recipes = await ApiService.fetchRecipes();
    setState(() {
      _recipes = recipes;
      _isLoading = false;
    });
  }

  void _navigateToDetail(Recipe recipe) {
    Navigator.pushNamed(context, '/recipeDetail', arguments: recipe);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Recipes')),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : ListView.builder(
                itemCount: _recipes.length,
                itemBuilder: (context, index) {
                  Recipe recipe = _recipes[index];
                  return ListTile(
                    title: Text(recipe.title),
                    subtitle: Text(recipe.description ?? ''),
                    onTap: () => _navigateToDetail(recipe),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/recipeForm');
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
