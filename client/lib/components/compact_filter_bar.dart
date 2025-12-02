import 'package:flutter/cupertino.dart';
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
              horizontal: AppSpacing.responsive(context, mobile: 16, tablet: 20, desktop: 24),
              vertical: AppSpacing.responsive(context, mobile: 12, tablet: 14, desktop: 16),
            ),
            child: Row(
              children: [
                // Search field - more compact
                Expanded(
                  child: Container(
                    height: AppBreakpoints.isDesktop(context)
                        ? 48
                        : AppBreakpoints.isTablet(context)
                            ? 44
                            : 36,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(
                        AppBreakpoints.isDesktop(context) ? 24 : 18,
                      ),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                    ),
                    child: CupertinoTextField(
                      controller: widget.searchController,
                      placeholder: 'Search recipes… e.g. chicken, broccoli, keto',
                      placeholderStyle: TextStyle(
                        fontSize: AppBreakpoints.isDesktop(context)
                            ? 16
                            : AppBreakpoints.isTablet(context)
                                ? 15
                                : 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      prefix: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Icon(
                          Icons.search,
                          size: AppBreakpoints.isDesktop(context)
                              ? 24
                              : AppBreakpoints.isTablet(context)
                                  ? 22
                                  : 18,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      decoration: const BoxDecoration(),
                      padding: EdgeInsets.symmetric(
                        horizontal: AppBreakpoints.isDesktop(context) ? 8 : 4,
                        vertical: AppBreakpoints.isDesktop(context) ? 12 : 8,
                      ),
                      style: TextStyle(
                        fontSize: AppBreakpoints.isDesktop(context)
                            ? 16
                            : AppBreakpoints.isTablet(context)
                                ? 15
                                : 14,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
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
                    borderRadius: BorderRadius.circular(
                      AppBreakpoints.isDesktop(context) ? 24 : 18,
                    ),
                    child: Container(
                      height: AppBreakpoints.isDesktop(context)
                          ? 48
                          : AppBreakpoints.isTablet(context)
                              ? 44
                              : 36,
                      width: AppBreakpoints.isDesktop(context)
                          ? 48
                          : AppBreakpoints.isTablet(context)
                              ? 44
                              : 36,
                      decoration: BoxDecoration(
                        color:
                            _isFilterExpanded ||
                                    widget.selectedDifficulty != 'All' ||
                                    widget.selectedTag != 'All'
                                ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.1)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(
                          AppBreakpoints.isDesktop(context) ? 24 : 18,
                        ),
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
                        size: AppBreakpoints.isDesktop(context)
                            ? 24
                            : AppBreakpoints.isTablet(context)
                                ? 22
                                : 18,
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
                                      style: AppBreakpoints.isDesktop(context)
                                          ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant
                                                .withValues(alpha: 0.8),
                                            fontWeight: FontWeight.w500,
                                          )
                                          : Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                            .withValues(alpha: 0.8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: AppBreakpoints.isDesktop(context) ? 6 : 4),
                                    Wrap(
                                      spacing: AppBreakpoints.isDesktop(context) ? 6 : 4,
                                      children:
                                          widget.difficulties.map((difficulty) {
                                            final isSelected =
                                                widget.selectedDifficulty ==
                                                difficulty;
                                            final borderRadius = AppBreakpoints.isDesktop(context) ? 16.0 : 12.0;
                                            return InkWell(
                                              onTap:
                                                  () => widget
                                                      .onDifficultySelected(
                                                        difficulty,
                                                      ),
                                              borderRadius:
                                                  BorderRadius.circular(borderRadius),
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: AppBreakpoints.isDesktop(context) ? 12 : 8,
                                                  vertical: AppBreakpoints.isDesktop(context) ? 6 : 4,
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
                                                      BorderRadius.circular(borderRadius),
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
                                                    fontSize: AppBreakpoints.isDesktop(context)
                                                        ? 14
                                                        : AppBreakpoints.isTablet(context)
                                                            ? 13
                                                            : 12,
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

                          SizedBox(height: AppBreakpoints.isDesktop(context) ? 16 : 12),

                          // Tag filter
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tags',
                                      style: AppBreakpoints.isDesktop(context)
                                          ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant
                                                .withValues(alpha: 0.8),
                                            fontWeight: FontWeight.w500,
                                          )
                                          : Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                            .withValues(alpha: 0.8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: AppBreakpoints.isDesktop(context) ? 6 : 4),
                                    Wrap(
                                      spacing: AppBreakpoints.isDesktop(context) ? 6 : 4,
                                      runSpacing: AppBreakpoints.isDesktop(context) ? 6 : 4,
                                      children:
                                          widget.availableTags.take(8).map((
                                            tag,
                                          ) {
                                            final isSelected =
                                                widget.selectedTag == tag;
                                            final tagBorderRadius = AppBreakpoints.isDesktop(context) ? 16.0 : 12.0;
                                            return InkWell(
                                              onTap:
                                                  () =>
                                                      widget.onTagSelected(tag),
                                              borderRadius:
                                                  BorderRadius.circular(tagBorderRadius),
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: AppBreakpoints.isDesktop(context) ? 12 : 8,
                                                  vertical: AppBreakpoints.isDesktop(context) ? 6 : 4,
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
                                                      BorderRadius.circular(tagBorderRadius),
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
                                                    fontSize: AppBreakpoints.isDesktop(context)
                                                        ? 14
                                                        : AppBreakpoints.isTablet(context)
                                                            ? 13
                                                            : 12,
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
                              padding: EdgeInsets.only(
                                top: AppBreakpoints.isDesktop(context) ? 12 : 8,
                              ),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: widget.onResetFilters,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: AppBreakpoints.isDesktop(context) ? 16 : 12,
                                      vertical: AppBreakpoints.isDesktop(context) ? 6 : 4,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Clear filters',
                                    style: TextStyle(
                                      fontSize: AppBreakpoints.isDesktop(context)
                                          ? 14
                                          : AppBreakpoints.isTablet(context)
                                              ? 13
                                              : 12,
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

