import 'package:flutter/material.dart';
import '../theme/theme.dart';

class PaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPreviousPage;
  final bool isLoading;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final void Function(int page)? onPageSelected;
  final int totalItems;
  final int itemsPerPage;

  const PaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPreviousPage,
    required this.isLoading,
    this.onPreviousPage,
    this.onNextPage,
    this.onPageSelected,
    required this.totalItems,
    required this.itemsPerPage,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Previous button - very compact
          SizedBox(
            width: 24,
            height: 24,
            child: IconButton(
              onPressed: hasPreviousPage && !isLoading ? onPreviousPage : null,
              icon: Icon(
                Icons.chevron_left,
                size: 16,
                color:
                    hasPreviousPage && !isLoading
                        ? theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.8,
                        )
                        : theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.3,
                        ),
              ),
              tooltip: 'Previous',
              padding: EdgeInsets.zero,
              splashRadius: 12,
            ),
          ),

          SizedBox(width: AppSpacing.xs / 2),

          // Current page indicator - minimal
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: Text(
              '$currentPage',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ),

          // Page separator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '/',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.4,
                ),
                fontSize: 10,
              ),
            ),
          ),

          // Total pages
          Text(
            '$totalPages',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontSize: 10,
            ),
          ),

          SizedBox(width: AppSpacing.xs / 2),

          // Next button - very compact
          SizedBox(
            width: 24,
            height: 24,
            child: IconButton(
              onPressed: hasNextPage && !isLoading ? onNextPage : null,
              icon: Icon(
                Icons.chevron_right,
                size: 16,
                color:
                    hasNextPage && !isLoading
                        ? theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.8,
                        )
                        : theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.3,
                        ),
              ),
              tooltip: 'Next',
              padding: EdgeInsets.zero,
              splashRadius: 12,
            ),
          ),

          // Loading indicator - tiny
          if (isLoading) ...[
            SizedBox(width: AppSpacing.xs / 2),
            SizedBox(
              height: 12,
              width: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
