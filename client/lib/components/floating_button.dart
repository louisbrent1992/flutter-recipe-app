import 'package:flutter/material.dart';
import 'package:recipease/components/button.dart';

class FloatingButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;
  final double iconSize;
  final bool showShadow;
  final String? tooltip;
  final IconData? icon;
  final bool isLoading;

  const FloatingButton({
    super.key,
    this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size = 40,
    this.iconSize = 24,
    this.showShadow = true,
    this.tooltip,
    this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 48,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Button(
          onPressed:
              onPressed ??
              () {
                Navigator.pushNamed(context, '/home');
              },
          backgroundColor: backgroundColor,
          iconColor: iconColor,
          tooltip: tooltip,
          size: size,
          iconSize: iconSize,
          showShadow: true, // We handle shadow in the container
          icon: isLoading ? Icons.hourglass_empty : icon ?? Icons.home_rounded,
        ),
      ),
    );
  }
}
