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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Error Icon
          Icon(_getErrorIcon(), size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          // Error Title
          Text(
            _getErrorTitle(),
            style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Error Message
          Text(
            message,
            style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.outline),
            textAlign: TextAlign.center,
          ),
          // Retry Button (if provided)
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ],
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
