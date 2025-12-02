import 'package:flutter/material.dart';
import 'credits_badge.dart';
import '../theme/theme.dart';

/// A customizable app bar component that supports multiple styles and configurations.
/// This component is designed to be reused across the application for consistent UI.
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? fullTitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double elevation;
  final Widget? flexibleSpace;
  final PreferredSizeWidget? bottom;
  final bool isTransparent;
  final bool useLogo;
  final double? logoHeight;
  final List<Widget>? floatingButtons;
  final bool showCreditsPill;

  const CustomAppBar({
    super.key,
    required this.title,
    this.fullTitle,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation = 0.0,
    this.flexibleSpace,
    this.bottom,
    this.isTransparent = false,
    this.useLogo = false,
    this.logoHeight = 60.0,
    this.floatingButtons,
    this.showCreditsPill = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTabletOrDesktop =
        AppBreakpoints.isTablet(context) || AppBreakpoints.isDesktop(context);

    // Show full title on tablet/desktop, short title on mobile
    final displayTitle =
        (fullTitle != null && isTabletOrDesktop) ? fullTitle! : title;

    // Always show full credits pill - users should see their credit counts
    const useCompactCredits = false;

    // Consistent spacing values for all screens
    final double actionsEndPadding = 0;

    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Use NavigationToolbar.kMiddleSpacing (16.0) for consistent title spacing
      titleSpacing: NavigationToolbar.kMiddleSpacing,
      title:
          useLogo
              ? Image.asset(
                'assets/icons/logo.png',
                height:
                    logoHeight ??
                    AppSizing.responsiveIconSize(
                      context,
                      mobile: 60.0,
                      tablet: 72.0,
                      desktop: 80.0,
                    ),
              )
              : Text(
                displayTitle,
                style: TextStyle(
                  fontSize: AppTypography.responsiveFontSize(
                    context,
                    mobile: 18.0,
                    tablet: 22.0,
                    desktop: 24.0,
                  ),
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
      centerTitle: centerTitle,
      automaticallyImplyLeading: automaticallyImplyLeading,

      foregroundColor: Theme.of(context).colorScheme.onSurface,
      elevation: elevation,
      flexibleSpace: flexibleSpace,

      bottom: bottom,
      leading:
          leading != null
              ? Builder(builder: (BuildContext context) => leading!)
              : null,

      actions: [
        if (showCreditsPill)
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: CreditsPill(
              compact: useCompactCredits,
              onTap: () => Navigator.pushNamed(context, '/subscription'),
              hasActionsToRight:
                  (floatingButtons != null && floatingButtons!.isNotEmpty) ||
                  (actions != null && actions!.isNotEmpty),
            ),
          ),
        if (floatingButtons != null) ...floatingButtons!,
        if (actions != null) ...actions!,
        // Consistent end padding for actions
        SizedBox(width: actionsEndPadding),
      ],
      iconTheme: IconThemeData(
        color: foregroundColor ?? theme.colorScheme.onSurface,
        size: AppSizing.responsiveIconSize(
          context,
          mobile: 24.0, // Default AppBar icon size
          tablet: 32.0, // Significantly larger for iPad
          desktop: 36.0, // Larger for desktop
        ),
      ),
      // Add support for system UI overlay
      systemOverlayStyle:
          theme.brightness == Brightness.dark
              ? null // Use system default for dark mode
              : null, // Use system default for light mode
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
    bottom != null
        ? kToolbarHeight + bottom!.preferredSize.height
        : kToolbarHeight,
  );
}
