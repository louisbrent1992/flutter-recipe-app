import 'package:flutter/material.dart';
import '../theme/theme.dart';

class FloatingBottomBar extends StatelessWidget {
  // Pagination parameters
  final bool showPagination;
  final int? currentPage;
  final int? totalPages;
  final bool? hasNextPage;
  final bool? hasPreviousPage;
  final bool? isLoading;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;

  const FloatingBottomBar({
    super.key,
    this.showPagination = false,
    this.currentPage,
    this.totalPages,
    this.hasNextPage,
    this.hasPreviousPage,
    this.isLoading,
    this.onPreviousPage,
    this.onNextPage,
  });

  void _handleNavigation(BuildContext context, int index) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    switch (index) {
      case 0:
        if (currentRoute != '/home') {
          Navigator.pushNamed(context, '/home');
        }
        break;
      case 1:
        if (currentRoute != '/discover') {
          Navigator.pushNamed(context, '/discover');
        }
        break;
      case 2:
        if (currentRoute != '/myRecipes') {
          Navigator.pushNamed(context, '/myRecipes');
        }
        break;
      case 3:
        if (currentRoute != '/generate') {
          Navigator.pushNamed(context, '/generate');
        }
        break;
      case 4:
        if (currentRoute != '/settings') {
          Navigator.pushNamed(context, '/settings');
        }
        break;
    }
  }

  bool _isNavSelected(BuildContext context, int index) {
    final currentRoute = ModalRoute.of(context)?.settings.name ?? '';

    switch (index) {
      case 0:
        return currentRoute == '/home';
      case 1:
        return currentRoute == '/discover';
      case 2:
        return currentRoute == '/myRecipes';
      case 3:
        return currentRoute == '/generate';
      case 4:
        return currentRoute == '/settings';
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine if pagination should be shown (only if more than 1 page)
    final shouldShowPagination =
        showPagination && totalPages != null && totalPages! > 1;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
      child: Container(
        height: shouldShowPagination
            ? (AppBreakpoints.isDesktop(context)
                ? 84
                : AppBreakpoints.isTablet(context)
                    ? 78
                    : 72)
            : (AppBreakpoints.isDesktop(context)
                ? 52
                : AppBreakpoints.isTablet(context)
                    ? 48
                    : 40),
        margin: EdgeInsets.all(
          AppSpacing.responsive(context, mobile: 16, tablet: 20, desktop: 24),
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(
            alpha: Theme.of(context).colorScheme.surfaceHeavy,
          ),
          borderRadius: BorderRadius.circular(
            shouldShowPagination
                ? (AppBreakpoints.isDesktop(context) ? 20 : 16)
                : (AppBreakpoints.isDesktop(context) ? 26 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.onSurface.withValues(
                alpha: Theme.of(context).colorScheme.shadowLight,
              ),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child:
            shouldShowPagination
                ? _buildWithPagination(context)
                : _buildNavOnly(context),
        ),
      ),
    );
  }

  Widget _buildNavOnly(BuildContext context) {
    final iconsList = [
      _buildMinimalNavIcon(
        context,
        icon: Icons.home_rounded,
        isSelected: _isNavSelected(context, 0),
        onTap: () => _handleNavigation(context, 0),
      ),
      _buildMinimalNavIcon(
        context,
        icon: Icons.explore_rounded,
        isSelected: _isNavSelected(context, 1),
        onTap: () => _handleNavigation(context, 1),
      ),
      _buildMinimalNavIcon(
        context,
        icon: Icons.restaurant_rounded,
        isSelected: _isNavSelected(context, 2),
        onTap: () => _handleNavigation(context, 2),
      ),
      _buildMinimalNavIcon(
        context,
        icon: Icons.auto_awesome_rounded,
        isSelected: _isNavSelected(context, 3),
        onTap: () => _handleNavigation(context, 3),
      ),
      _buildMinimalNavIcon(
        context,
        icon: Icons.person_rounded,
        isSelected: _isNavSelected(context, 4),
        onTap: () => _handleNavigation(context, 4),
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: iconsList,
    );
  }

  Widget _buildWithPagination(BuildContext context) {
    final iconsList = [
      _buildMinimalNavIcon(
        context,
        icon: Icons.home_rounded,
        isSelected: _isNavSelected(context, 0),
        onTap: () => _handleNavigation(context, 0),
      ),
      _buildMinimalNavIcon(
        context,
        icon: Icons.explore_rounded,
        isSelected: _isNavSelected(context, 1),
        onTap: () => _handleNavigation(context, 1),
      ),
      _buildMinimalNavIcon(
        context,
        icon: Icons.restaurant_rounded,
        isSelected: _isNavSelected(context, 2),
        onTap: () => _handleNavigation(context, 2),
      ),
      _buildMinimalNavIcon(
        context,
        icon: Icons.auto_awesome_rounded,
        isSelected: _isNavSelected(context, 3),
        onTap: () => _handleNavigation(context, 3),
      ),
      _buildMinimalNavIcon(
        context,
        icon: Icons.person_rounded,
        isSelected: _isNavSelected(context, 4),
        onTap: () => _handleNavigation(context, 4),
      ),
    ];

    return Column(
      children: [
        // Navigation row
        SizedBox(
          height: AppBreakpoints.isDesktop(context)
              ? 52
              : AppBreakpoints.isTablet(context)
                  ? 48
                  : 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: iconsList,
          ),
        ),

        // Divider
        Container(
          height: 0.5,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          color: Theme.of(context).colorScheme.outline.withValues(
            alpha: Theme.of(context).colorScheme.overlayMedium,
          ),
        ),

        // Pagination row
        SizedBox(height: 31.5, child: _buildCompactPagination(context)),
      ],
    );
  }

  Widget _buildCompactPagination(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Previous button
        SizedBox(
          width: 24,
          height: 24,
          child: IconButton(
            onPressed:
                (hasPreviousPage ?? false) && !(isLoading ?? false)
                    ? onPreviousPage
                    : null,
            icon: Icon(
              Icons.chevron_left,
              size: 16,
              color:
                  (hasPreviousPage ?? false) && !(isLoading ?? false)
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

        const SizedBox(width: 4),

        // Current page indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(
              alpha: Theme.of(context).colorScheme.overlayMedium,
            ),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(
                alpha: Theme.of(context).colorScheme.overlayHeavy,
              ),
              width: 0.5,
            ),
          ),
          child: Text(
            '${currentPage ?? 1}',
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
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(
                alpha: Theme.of(context).colorScheme.alphaMedium,
              ),
              fontSize: 10,
            ),
          ),
        ),

        // Total pages
        Text(
          '${totalPages ?? 1}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(
              alpha: Theme.of(context).colorScheme.alphaHigh,
            ),
            fontSize: 10,
          ),
        ),

        const SizedBox(width: 4),

        // Next button
        SizedBox(
          width: 24,
          height: 24,
          child: IconButton(
            onPressed:
                (hasNextPage ?? false) && !(isLoading ?? false)
                    ? onNextPage
                    : null,
            icon: Icon(
              Icons.chevron_right,
              size: 16,
              color:
                  (hasNextPage ?? false) && !(isLoading ?? false)
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

        // Loading indicator
        if (isLoading ?? false) ...[
          const SizedBox(width: 4),
          SizedBox(
            height: 12,
            width: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1,
              color: Theme.of(context).colorScheme.primary.withValues(
                alpha: Theme.of(context).colorScheme.alphaMedium,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMinimalNavIcon(
    BuildContext context, {
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final borderRadius = AppBreakpoints.isDesktop(context) ? 16.0 : 12.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppBreakpoints.isDesktop(context)
              ? 20
              : AppBreakpoints.isTablet(context)
                  ? 18
                  : 16,
          vertical: AppBreakpoints.isDesktop(context)
              ? 10
              : AppBreakpoints.isTablet(context)
                  ? 9
                  : 8,
        ),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? theme.colorScheme.primary.withValues(
                    alpha: theme.colorScheme.overlayMedium,
                  )
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Icon(
          icon,
          size: AppSizing.responsiveIconSize(
            context,
            mobile: 18,
            tablet: 22,
            desktop: 24,
          ),
          color:
              isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
