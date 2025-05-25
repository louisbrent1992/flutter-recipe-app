import 'package:flutter/material.dart';
import 'package:recipease/components/home_button.dart';

class FloatingSaveButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;
  final double iconSize;
  final bool showShadow;
  final String? tooltip;
  final bool isLoading;

  const FloatingSaveButton({
    super.key,
    this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size = 40,
    this.iconSize = 24,
    this.showShadow = true,
    this.tooltip,
    this.isLoading = false,
  });

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
          onPressed: isLoading ? null : onPressed,
          backgroundColor: backgroundColor,
          iconColor: iconColor,
          tooltip: tooltip ?? 'Save recipe',
          size: size,
          iconSize: iconSize,
          showShadow: false, // We handle shadow in the container
          icon: isLoading ? Icons.hourglass_empty : Icons.save,
        ),
      ),
    );
  }
}
