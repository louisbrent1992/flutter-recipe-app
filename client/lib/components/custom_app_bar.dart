import 'package:flutter/material.dart';

/// A customizable app bar component that supports multiple styles and configurations.
/// This component is designed to be reused across the application for consistent UI.
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
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

  const CustomAppBar({
    super.key,
    required this.title,
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
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      title:
          useLogo
              ? Image.asset('icons/logo.png', height: logoHeight)
              : Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: foregroundColor ?? theme.colorScheme.onPrimary,
                ),
              ),
      centerTitle: centerTitle,
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor: backgroundColor ?? theme.colorScheme.primary,
      foregroundColor: foregroundColor ?? theme.colorScheme.onPrimary,
      elevation: elevation,
      flexibleSpace: flexibleSpace,
      bottom: bottom,
      leading:
          leading != null
              ? Builder(builder: (BuildContext context) => leading!)
              : null,
      actions: actions,
      iconTheme: IconThemeData(
        color: foregroundColor ?? theme.colorScheme.onPrimary,
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
