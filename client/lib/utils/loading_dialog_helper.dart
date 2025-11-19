import 'dart:ui';
import 'package:flutter/material.dart';

/// Centralized loading dialog utilities
/// 
/// Provides consistent animated loading dialogs across the app
class LoadingDialogHelper {
  /// Show an animated loading dialog with blur effect
  /// 
  /// [context] - BuildContext to show the dialog
  /// [message] - Loading message to display
  /// [icon] - Optional icon to display
  /// 
  /// Returns a Future that completes when the dialog is shown.
  /// Call `Navigator.pop(context)` to dismiss the dialog.
  static Future<void> show(
    BuildContext context, {
    required String message,
    IconData? icon,
  }) {
    return showGeneralDialog(
      context: context,
      barrierLabel: message,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 8.0 * curved.value,
            sigmaY: 8.0 * curved.value,
          ),
          child: Opacity(
            opacity: animation.value,
            child: Transform.scale(
              scale: 0.98 + 0.02 * curved.value,
              child: Center(
                child: _LoadingDialog(
                  message: message,
                  icon: icon,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Dismiss the currently shown loading dialog
  static void dismiss(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  /// Show loading dialog and execute an async operation
  /// 
  /// Automatically dismisses the dialog when the operation completes.
  /// 
  /// [context] - BuildContext to show the dialog
  /// [message] - Loading message to display
  /// [operation] - Async function to execute
  /// [icon] - Optional icon to display
  /// 
  /// Returns the result of the operation or null if an error occurs.
  static Future<T?> showWhile<T>(
    BuildContext context, {
    required String message,
    required Future<T> Function() operation,
    IconData? icon,
  }) async {
    try {
      if (context.mounted) {
        await show(context, message: message, icon: icon);
      }

      final result = await operation();

      if (context.mounted) {
        dismiss(context);
      }

      return result;
    } catch (e) {
      if (context.mounted) {
        dismiss(context);
      }
      rethrow;
    }
  }
}

/// Internal loading dialog widget
class _LoadingDialog extends StatelessWidget {
  final String message;
  final IconData? icon;

  const _LoadingDialog({
    required this.message,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(32),
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon or default loading indicator
          if (icon != null) ...[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
          ] else ...[
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Message
          Text(
            message,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Subtitle
          Text(
            'Please wait...',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

