import 'package:flutter/material.dart';

class ErrorDisplay extends StatelessWidget {
  final String message;
  final int? statusCode;
  final VoidCallback? onRetry;
  final bool isNetworkError;
  final bool isAuthError;
  final bool isFormatError;

  const ErrorDisplay({
    super.key,
    required this.message,
    this.statusCode,
    this.onRetry,
    this.isNetworkError = false,
    this.isAuthError = false,
    this.isFormatError = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error Icon
            Icon(_getErrorIcon(), size: 64, color: colorScheme.error),
            const SizedBox(height: 24),
            // Error Title
            Text(
              _getErrorTitle(),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Retry Button (if provided)
            if (onRetry != null)
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getErrorIcon() {
    if (isNetworkError) {
      return Icons.wifi_off_rounded;
    } else if (isAuthError) {
      return Icons.lock_outline;
    } else if (isFormatError) {
      return Icons.error_outline;
    } else {
      return Icons.warning_amber_rounded;
    }
  }

  String _getErrorTitle() {
    if (isNetworkError) {
      return 'Connection Error';
    } else if (isAuthError) {
      return 'Authentication Error';
    } else if (isFormatError) {
      return 'Data Format Error';
    } else {
      return 'Something Went Wrong';
    }
  }
}
