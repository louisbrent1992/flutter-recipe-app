import 'package:flutter/material.dart';

class RecipeFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final String selectedDifficulty;
  final String selectedTag;
  final List<String> difficulties;
  final List<String> availableTags;
  final Function(String) onSearchChanged;
  final Function(String) onDifficultySelected;
  final Function(String) onTagSelected;
  final VoidCallback? onResetFilters;
  final bool showResetButton;
  final double filtersOpacity;

  const RecipeFilterBar({
    super.key,
    required this.searchController,
    required this.searchQuery,
    required this.selectedDifficulty,
    required this.selectedTag,
    required this.difficulties,
    required this.availableTags,
    required this.onSearchChanged,
    required this.onDifficultySelected,
    required this.onTagSelected,
    this.onResetFilters,
    this.showResetButton = false,
    this.filtersOpacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: searchController,
          textAlignVertical: TextAlignVertical.bottom,
          decoration: InputDecoration(
            hintText: 'Search recipes...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(50)),
            constraints: const BoxConstraints(maxHeight: 35),
            suffixIcon:
                searchQuery.isNotEmpty
                    ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                    )
                    : null,
          ),
          onChanged: onSearchChanged,
        ),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: filtersOpacity,
          child:
              filtersOpacity > 0
                  ? Column(
                    children: [
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const Text('Difficulty: '),
                            ...difficulties.map(
                              (difficulty) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: FilterChip(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  label: Text(difficulty),
                                  selected: selectedDifficulty == difficulty,
                                  onSelected:
                                      (selected) =>
                                          onDifficultySelected(difficulty),
                                ),
                              ),
                            ),
                            if (showResetButton)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: TextButton.icon(
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Reset Filters'),
                                  onPressed: onResetFilters,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const Text('Tags: '),
                            ...availableTags.map(
                              (tag) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: FilterChip(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  label: Text(tag),
                                  selected: selectedTag == tag,
                                  onSelected: (selected) => onTagSelected(tag),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                  : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
