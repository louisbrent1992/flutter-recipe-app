import 'package:flutter/material.dart';

class ErrorDisplay extends StatelessWidget {
  final String message;
  final String? title;
  final String? subtitle;
  final int? statusCode;
  final VoidCallback? onRetry;
  final bool isNetworkError;
  final bool isAuthError;
  final bool isFormatError;
  final IconData? customIcon;
  final Widget? actionButton;

  const ErrorDisplay({
    super.key,
    required this.message,
    this.title,
    this.subtitle,
    this.statusCode,
    this.onRetry,
    this.isNetworkError = false,
    this.isAuthError = false,
    this.isFormatError = false,
    this.customIcon,
    this.actionButton,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error Icon
            Icon(
              customIcon ?? _getErrorIcon(),
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 20),
            // Error Title
            Text(
              title ?? _getErrorTitle(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Error Subtitle/Message - shorter, friendlier
            Text(
              subtitle ?? _getShortMessage(),
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            // Retry Button or Custom Action (if provided)
            if (onRetry != null || actionButton != null) ...[
              const SizedBox(height: 24),
              actionButton ?? TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Try Again'),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getErrorIcon() {
    if (isNetworkError) {
      return Icons.wifi_off_rounded;
    } else if (isAuthError) {
      return Icons.lock_outline_rounded;
    } else if (isFormatError) {
      return Icons.error_outline_rounded;
    } else {
      return Icons.cloud_off_rounded;
    }
  }

  String _getErrorTitle() {
    if (isNetworkError) {
      return 'You\'re Offline';
    } else if (isAuthError) {
      return 'Sign In Required';
    } else if (isFormatError) {
      return 'Something Went Wrong';
    } else {
      return 'Couldn\'t Load';
    }
  }

  /// Returns a shorter, friendlier message instead of the full error
  String _getShortMessage() {
    if (isNetworkError) {
      return 'Check your connection and try again';
    } else if (isAuthError) {
      return 'Please sign in to continue';
    } else if (isFormatError) {
      return 'We ran into an issue. Try again later.';
    } else {
      return 'Tap to retry';
    }
  }
}
