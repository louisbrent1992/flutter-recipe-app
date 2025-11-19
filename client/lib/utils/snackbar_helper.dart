import 'package:flutter/material.dart';

/// Centralized SnackBar utilities for consistent UI feedback
/// 
/// Provides standardized success, error, warning, and info messages
class SnackBarHelper {
  // Default durations
  static const Duration _shortDuration = Duration(seconds: 2);
  static const Duration _mediumDuration = Duration(seconds: 4);
  static const Duration _longDuration = Duration(seconds: 8);

  // Success colors
  static const Color _successColor = Color(0xFF4CAF50); // Material green

  /// Show a success message (green)
  /// 
  /// [message] - The success message to display
  /// [action] - Optional SnackBarAction
  /// [duration] - How long to show the message (default: 4 seconds)
  static void showSuccess(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    Duration? duration,
  }) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: _successColor,
      icon: Icons.check_circle_outline,
      action: action,
      duration: duration ?? _mediumDuration,
    );
  }

  /// Show an error message (red)
  /// 
  /// [message] - The error message to display
  /// [action] - Optional SnackBarAction
  /// [duration] - How long to show the message (default: 4 seconds)
  /// [showDismiss] - Whether to show a dismiss button (default: true)
  static void showError(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    Duration? duration,
    bool showDismiss = true,
  }) {
    final theme = Theme.of(context);
    _showSnackBar(
      context,
      message: message,
      backgroundColor: theme.colorScheme.error,
      icon: Icons.error_outline,
      action: action ??
          (showDismiss
              ? SnackBarAction(
                  label: 'Dismiss',
                  textColor: theme.colorScheme.onError,
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                )
              : null),
      duration: duration ?? _mediumDuration,
    );
  }

  /// Show a warning message (orange)
  /// 
  /// [message] - The warning message to display
  /// [action] - Optional SnackBarAction
  /// [duration] - How long to show the message (default: 4 seconds)
  static void showWarning(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    Duration? duration,
  }) {
    _showSnackBar(
      context,
      message: message,
      backgroundColor: Colors.orange,
      icon: Icons.warning_amber_outlined,
      action: action,
      duration: duration ?? _mediumDuration,
    );
  }

  /// Show an info message (blue)
  /// 
  /// [message] - The info message to display
  /// [action] - Optional SnackBarAction
  /// [duration] - How long to show the message (default: 2 seconds)
  static void showInfo(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    Duration? duration,
  }) {
    final theme = Theme.of(context);
    _showSnackBar(
      context,
      message: message,
      backgroundColor: theme.colorScheme.primary,
      icon: Icons.info_outline,
      action: action,
      duration: duration ?? _shortDuration,
    );
  }

  /// Show a simple message without icon (uses theme colors)
  /// 
  /// [message] - The message to display
  /// [action] - Optional SnackBarAction
  /// [duration] - How long to show the message (default: 2 seconds)
  static void show(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    Duration? duration,
    Color? backgroundColor,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        duration: duration ?? _shortDuration,
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Show a long-duration message (8 seconds)
  /// Useful for important messages that users should read
  static void showLong(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    bool isError = false,
  }) {
    if (isError) {
      showError(context, message, action: action, duration: _longDuration);
    } else {
      showSuccess(context, message, action: action, duration: _longDuration);
    }
  }

  /// Internal method to show styled SnackBar
  static void _showSnackBar(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    IconData? icon,
    SnackBarAction? action,
    required Duration duration,
  }) {
    final theme = Theme.of(context);

    // Hide any existing snackbars
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // Show new snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: theme.colorScheme.onPrimary,
                size: 20,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        action: action,
      ),
    );
  }
}

/// Extension method for brevity
extension SnackBarExtension on BuildContext {
  /// Quick access to SnackBarHelper methods
  void showSuccessSnackBar(String message, {SnackBarAction? action}) {
    SnackBarHelper.showSuccess(this, message, action: action);
  }

  void showErrorSnackBar(String message, {SnackBarAction? action}) {
    SnackBarHelper.showError(this, message, action: action);
  }

  void showWarningSnackBar(String message, {SnackBarAction? action}) {
    SnackBarHelper.showWarning(this, message, action: action);
  }

  void showInfoSnackBar(String message, {SnackBarAction? action}) {
    SnackBarHelper.showInfo(this, message, action: action);
  }
}

