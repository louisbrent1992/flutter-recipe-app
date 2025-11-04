import 'package:flutter/material.dart';
import '../theme/theme.dart';

class CompactFilterBar extends StatefulWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final String selectedDifficulty;
  final String selectedTag;
  final List<String> difficulties;
  final List<String> availableTags;
  final void Function(String) onSearchChanged;
  final void Function(String) onDifficultySelected;
  final void Function(String) onTagSelected;
  final VoidCallback onResetFilters;
  final bool showResetButton;

  const CompactFilterBar({
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
    required this.onResetFilters,
    required this.showResetButton,
  });

  @override
  State<CompactFilterBar> createState() => _CompactFilterBarState();
}

class _CompactFilterBarState extends State<CompactFilterBar> {
  bool _isFilterExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // Compact header with search and expand button
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                // Search field - more compact
                Expanded(
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                    ),
                    child: TextField(
                      controller: widget.searchController,
                      decoration: InputDecoration(
                        hintText: 'Search recipes… e.g. chicken, broccoli, keto',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 18,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      style: const TextStyle(fontSize: 14),
                      onChanged: widget.onSearchChanged,
                    ),
                  ),
                ),

                SizedBox(width: AppSpacing.sm),

                // Filter toggle button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _isFilterExpanded = !_isFilterExpanded;
                      });
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      height: 36,
                      width: 36,
                      decoration: BoxDecoration(
                        color:
                            _isFilterExpanded ||
                                    widget.selectedDifficulty != 'All' ||
                                    widget.selectedTag != 'All'
                                ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.1)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color:
                              _isFilterExpanded ||
                                      widget.selectedDifficulty != 'All' ||
                                      widget.selectedTag != 'All'
                                  ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.3)
                                  : Theme.of(
                                    context,
                                  ).colorScheme.outline.withValues(alpha: 0.2),
                          width: 0.5,
                        ),
                      ),
                      child: Icon(
                        _isFilterExpanded ? Icons.expand_less : Icons.tune,
                        size: 18,
                        color:
                            widget.selectedDifficulty != 'All' ||
                                    widget.selectedTag != 'All'
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Expandable filter section
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            height: _isFilterExpanded ? null : 0,
            child:
                _isFilterExpanded
                    ? Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        0,
                        AppSpacing.md,
                        AppSpacing.sm,
                      ),
                      child: Column(
                        children: [
                          // Quick filter chips
                          Row(
                            children: [
                              // Difficulty filter
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Difficulty',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                            .withValues(alpha: 0.8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 4,
                                      children:
                                          widget.difficulties.map((difficulty) {
                                            final isSelected =
                                                widget.selectedDifficulty ==
                                                difficulty;
                                            return InkWell(
                                              onTap:
                                                  () => widget
                                                      .onDifficultySelected(
                                                        difficulty,
                                                      ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      isSelected
                                                          ? Theme.of(context)
                                                              .colorScheme
                                                              .primary
                                                              .withValues(
                                                                alpha: 0.1,
                                                              )
                                                          : Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color:
                                                        isSelected
                                                            ? Theme.of(context)
                                                                .colorScheme
                                                                .primary
                                                                .withValues(
                                                                  alpha: 0.3,
                                                                )
                                                            : Theme.of(context)
                                                                .colorScheme
                                                                .outline
                                                                .withValues(
                                                                  alpha: 0.2,
                                                                ),
                                                    width: 0.5,
                                                  ),
                                                ),
                                                child: Text(
                                                  difficulty,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        isSelected
                                                            ? Theme.of(context)
                                                                .colorScheme
                                                                .primary
                                                            : Theme.of(context)
                                                                .colorScheme
                                                                .onSurfaceVariant
                                                                .withValues(
                                                                  alpha: 0.8,
                                                                ),
                                                    fontWeight:
                                                        isSelected
                                                            ? FontWeight.w600
                                                            : FontWeight.normal,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Tag filter
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tags',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                            .withValues(alpha: 0.8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children:
                                          widget.availableTags.take(8).map((
                                            tag,
                                          ) {
                                            final isSelected =
                                                widget.selectedTag == tag;
                                            return InkWell(
                                              onTap:
                                                  () =>
                                                      widget.onTagSelected(tag),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      isSelected
                                                          ? Theme.of(context)
                                                              .colorScheme
                                                              .primary
                                                              .withValues(
                                                                alpha: 0.1,
                                                              )
                                                          : Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color:
                                                        isSelected
                                                            ? Theme.of(context)
                                                                .colorScheme
                                                                .primary
                                                                .withValues(
                                                                  alpha: 0.3,
                                                                )
                                                            : Theme.of(context)
                                                                .colorScheme
                                                                .outline
                                                                .withValues(
                                                                  alpha: 0.2,
                                                                ),
                                                    width: 0.5,
                                                  ),
                                                ),
                                                child: Text(
                                                  tag,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        isSelected
                                                            ? Theme.of(context)
                                                                .colorScheme
                                                                .primary
                                                            : Theme.of(context)
                                                                .colorScheme
                                                                .onSurfaceVariant
                                                                .withValues(
                                                                  alpha: 0.8,
                                                                ),
                                                    fontWeight:
                                                        isSelected
                                                            ? FontWeight.w600
                                                            : FontWeight.normal,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // Reset button
                          if (widget.showResetButton)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: widget.onResetFilters,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Clear filters',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
