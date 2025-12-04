import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/theme.dart';
import '../components/app_tutorial.dart';

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
  final void Function(int page)? onGoToPage; // New: direct page navigation

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
    this.onGoToPage,
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

    // Get the safe area padding to lift the bar above the home indicator
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: Container(
          height:
              shouldShowPagination
                  ? (AppBreakpoints.isDesktop(context)
                      ? 84
                      : AppBreakpoints.isTablet(context)
                      ? 80
                      : 72)
                  : (AppBreakpoints.isDesktop(context)
                      ? 52
                      : AppBreakpoints.isTablet(context)
                      ? 48
                      : 40),
          margin: EdgeInsets.only(
            left: AppSpacing.responsive(context, mobile: 16, tablet: 20, desktop: 24),
            right: AppSpacing.responsive(context, mobile: 16, tablet: 20, desktop: 24),
            top: AppSpacing.responsive(context, mobile: 16, tablet: 20, desktop: 24),
            // Add bottomPadding to the base spacing so it clears the home indicator
            bottom: AppSpacing.responsive(context, mobile: 16, tablet: 20, desktop: 24) + bottomPadding,
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
      TutorialShowcase(
        showcaseKey: TutorialKeys.bottomNavHome,
        title: 'Dashboard 🏠',
        description:
            'Your central hub for recipes, features, and daily inspiration.',
        isCircular: true,
        targetPadding: const EdgeInsets.all(12),
        child: _buildMinimalNavIcon(
          context,
          icon: Icons.home_rounded,
          isSelected: _isNavSelected(context, 0),
          onTap: () => _handleNavigation(context, 0),
        ),
      ),
      TutorialShowcase(
        showcaseKey: TutorialKeys.bottomNavDiscover,
        title: 'Explore 🔍',
        description: 'Browse thousands of curated recipes with smart filters.',
        isCircular: true,
        targetPadding: const EdgeInsets.all(12),
        child: _buildMinimalNavIcon(
          context,
          icon: Icons.explore_rounded,
          isSelected: _isNavSelected(context, 1),
          onTap: () => _handleNavigation(context, 1),
        ),
      ),
      TutorialShowcase(
        showcaseKey: TutorialKeys.bottomNavMyRecipes,
        title: 'My Kitchen 📖',
        description: 'Access all your personal recipes and collections.',
        isCircular: true,
        targetPadding: const EdgeInsets.all(12),
        child: _buildMinimalNavIcon(
          context,
          icon: Icons.restaurant_rounded,
          isSelected: _isNavSelected(context, 2),
          onTap: () => _handleNavigation(context, 2),
        ),
      ),
      TutorialShowcase(
        showcaseKey: TutorialKeys.bottomNavGenerate,
        title: 'AI Chef ✨',
        description:
            'Create unique recipes instantly based on your ingredients and preferences.',
        isCircular: true,
        targetPadding: const EdgeInsets.all(12),
        child: _buildMinimalNavIcon(
          context,
          icon: Icons.auto_awesome_rounded,
          isSelected: _isNavSelected(context, 3),
          onTap: () => _handleNavigation(context, 3),
        ),
      ),
      TutorialShowcase(
        showcaseKey: TutorialKeys.bottomNavSettings,
        title: 'Customize ⚙️',
        description: 'Manage your profile, preferences, and subscription.',
        isCircular: true,
        targetPadding: const EdgeInsets.all(12),
        child: _buildMinimalNavIcon(
          context,
          icon: Icons.person_rounded,
          isSelected: _isNavSelected(context, 4),
          onTap: () => _handleNavigation(context, 4),
        ),
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: iconsList,
    );
  }

  Widget _buildWithPagination(BuildContext context) {
    final iconsList = [
      TutorialShowcase(
        showcaseKey: TutorialKeys.bottomNavHome,
        title: 'Dashboard 🏠',
        description:
            'Your central hub for recipes, features, and daily inspiration.',
        isCircular: true,
        targetPadding: const EdgeInsets.all(12),
        child: _buildMinimalNavIcon(
          context,
          icon: Icons.home_rounded,
          isSelected: _isNavSelected(context, 0),
          onTap: () => _handleNavigation(context, 0),
        ),
      ),
      TutorialShowcase(
        showcaseKey: TutorialKeys.bottomNavDiscover,
        title: 'Explore 🔍',
        description: 'Browse thousands of curated recipes with smart filters.',
        isCircular: true,
        targetPadding: const EdgeInsets.all(12),
        child: _buildMinimalNavIcon(
          context,
          icon: Icons.explore_rounded,
          isSelected: _isNavSelected(context, 1),
          onTap: () => _handleNavigation(context, 1),
        ),
      ),
      TutorialShowcase(
        showcaseKey: TutorialKeys.bottomNavMyRecipes,
        title: 'My Kitchen 📖',
        description: 'Access all your personal recipes and collections.',
        isCircular: true,
        targetPadding: const EdgeInsets.all(12),
        child: _buildMinimalNavIcon(
          context,
          icon: Icons.restaurant_rounded,
          isSelected: _isNavSelected(context, 2),
          onTap: () => _handleNavigation(context, 2),
        ),
      ),
      TutorialShowcase(
        showcaseKey: TutorialKeys.bottomNavGenerate,
        title: 'AI Chef ✨',
        description:
            'Create unique recipes instantly based on your ingredients and preferences.',
        isCircular: true,
        targetPadding: const EdgeInsets.all(12),
        child: _buildMinimalNavIcon(
          context,
          icon: Icons.auto_awesome_rounded,
          isSelected: _isNavSelected(context, 3),
          onTap: () => _handleNavigation(context, 3),
        ),
      ),
      TutorialShowcase(
        showcaseKey: TutorialKeys.bottomNavSettings,
        title: 'Customize ⚙️',
        description: 'Manage your profile, preferences, and subscription.',
        isCircular: true,
        targetPadding: const EdgeInsets.all(12),
        child: _buildMinimalNavIcon(
          context,
          icon: Icons.person_rounded,
          isSelected: _isNavSelected(context, 4),
          onTap: () => _handleNavigation(context, 4),
        ),
      ),
    ];

    return Column(
      children: [
        // Navigation row
        SizedBox(
          height:
              AppBreakpoints.isDesktop(context)
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
    final current = currentPage ?? 1;
    final total = totalPages ?? 1;
    final canGoPrev = (hasPreviousPage ?? false) && !(isLoading ?? false);
    final canGoNext = (hasNextPage ?? false) && !(isLoading ?? false);
    final canJumpBack10 = current > 1 && !(isLoading ?? false);
    final canJumpForward10 = current < total && !(isLoading ?? false);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Jump back 10 pages button (<<)
        if (total > 10) ...[
          SizedBox(
            width: 24,
            height: 24,
            child: IconButton(
              onPressed:
                  canJumpBack10 && onGoToPage != null
                      ? () => onGoToPage!((current - 10).clamp(1, total))
                      : null,
              icon: Icon(
                Icons.keyboard_double_arrow_left,
                size: 16,
                color:
                    canJumpBack10
                        ? theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.8,
                        )
                        : theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.3,
                        ),
              ),
              tooltip: 'Back 10 pages',
              padding: EdgeInsets.zero,
              splashRadius: 12,
            ),
          ),
        ],

        // Previous button
        SizedBox(
          width: 24,
          height: 24,
          child: IconButton(
            onPressed: canGoPrev ? onPreviousPage : null,
            icon: Icon(
              Icons.chevron_left,
              size: 16,
              color:
                  canGoPrev
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

        // Tappable page indicator - opens "Go to page" dialog
        GestureDetector(
          onTap:
              total > 1 && onGoToPage != null && !(isLoading ?? false)
                  ? () => _showGoToPageDialog(context, current, total)
                  : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(
                alpha: theme.colorScheme.overlayMedium,
              ),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(
                  alpha: theme.colorScheme.overlayHeavy,
                ),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$current',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
                Text(
                  ' / $total',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: theme.colorScheme.alphaHigh,
                    ),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 4),

        // Next button
        SizedBox(
          width: 24,
          height: 24,
          child: IconButton(
            onPressed: canGoNext ? onNextPage : null,
            icon: Icon(
              Icons.chevron_right,
              size: 16,
              color:
                  canGoNext
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

        // Jump forward 10 pages button (>>)
        if (total > 10) ...[
          SizedBox(
            width: 24,
            height: 24,
            child: IconButton(
              onPressed:
                  canJumpForward10 && onGoToPage != null
                      ? () => onGoToPage!((current + 10).clamp(1, total))
                      : null,
              icon: Icon(
                Icons.keyboard_double_arrow_right,
                size: 16,
                color:
                    canJumpForward10
                        ? theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.8,
                        )
                        : theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.3,
                        ),
              ),
              tooltip: 'Forward 10 pages',
              padding: EdgeInsets.zero,
              splashRadius: 12,
            ),
          ),
        ],

        // Loading indicator
        if (isLoading ?? false) ...[
          const SizedBox(width: 4),
          SizedBox(
            height: 12,
            width: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1,
              color: theme.colorScheme.primary.withValues(
                alpha: theme.colorScheme.alphaMedium,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showGoToPageDialog(
    BuildContext context,
    int currentPage,
    int totalPages,
  ) {
    final controller = TextEditingController(text: currentPage.toString());
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Go to Page',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoTextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  placeholder: '1 - $totalPages',
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  placeholderStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  onSubmitted: (value) {
                    final page = int.tryParse(value);
                    if (page != null && page >= 1 && page <= totalPages) {
                      Navigator.pop(context);
                      onGoToPage?.call(page);
                    }
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter a page between 1 and $totalPages',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final page = int.tryParse(controller.text);
                  if (page != null && page >= 1 && page <= totalPages) {
                    Navigator.pop(context);
                    onGoToPage?.call(page);
                  }
                },
                child: const Text('Go'),
              ),
            ],
          ),
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
            horizontal:
                AppBreakpoints.isDesktop(context)
                    ? 20
                    : AppBreakpoints.isTablet(context)
                    ? 18
                    : 16,
            vertical:
                AppBreakpoints.isDesktop(context)
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
