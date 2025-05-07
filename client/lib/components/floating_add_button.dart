import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipease/components/home_button.dart';
import 'package:recipease/providers/auth_provider.dart';

class FloatingAddButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;
  final double iconSize;
  final bool showShadow;
  final String? tooltip;
  const FloatingAddButton({
    super.key,
    this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size = 40,
    this.iconSize = 24,
    this.showShadow = true,
    this.tooltip,
  });

  void handleOnPressed(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.user == null) {
      // Show login dialog if not authenticated
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Login Required'),
              content: const Text('You need to login to create recipes.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/login');
                  },
                  child: const Text('Login'),
                ),
              ],
            ),
      );
    } else {
      Navigator.pushNamed(context, '/recipeEdit');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 16,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: HomeButton(
          onPressed: onPressed ?? () => handleOnPressed(context),
          backgroundColor: backgroundColor,
          iconColor: iconColor,
          tooltip: tooltip ?? 'Add recipe',
          size: size,
          iconSize: iconSize,
          showShadow: false, // We handle shadow in the container
          icon: Icons.add,
        ),
      ),
    );
  }
}
