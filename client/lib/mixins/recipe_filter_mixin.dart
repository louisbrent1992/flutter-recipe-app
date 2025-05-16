import 'package:recipease/models/recipe.dart';

mixin RecipeFilterMixin {
  List<Recipe> filterRecipes(
    List<Recipe> recipes, {
    required String searchQuery,
    required String selectedDifficulty,
    required String selectedTag,
  }) {
    return recipes.where((recipe) {
      final matchesSearch =
          searchQuery.isEmpty ||
          recipe.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          recipe.description.toLowerCase().contains(
            searchQuery.toLowerCase(),
          ) ||
          recipe.ingredients.any(
            (ingredient) =>
                ingredient.toLowerCase().contains(searchQuery.toLowerCase()),
          ) ||
          recipe.instructions.any(
            (instruction) =>
                instruction.toLowerCase().contains(searchQuery.toLowerCase()),
          ) ||
          recipe.tags.any(
            (tag) => tag.toLowerCase().contains(searchQuery.toLowerCase()),
          ) ||
          recipe.difficulty.toLowerCase().contains(searchQuery.toLowerCase());

      final matchesDifficulty =
          selectedDifficulty == 'All' ||
          recipe.difficulty == selectedDifficulty;

      final matchesTag =
          selectedTag == 'All' || recipe.tags.contains(selectedTag);

      return matchesSearch && matchesDifficulty && matchesTag;
    }).toList();
  }
}
