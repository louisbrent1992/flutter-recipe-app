import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:recipease/theme/theme.dart';

/// Centralized loading dialog utilities
///
/// Provides consistent animated loading dialogs across the app
class LoadingDialogHelper {
  /// Show an animated loading dialog with blur effect
  ///
  /// [context] - BuildContext to show the dialog
  /// [message] - Loading message to display
  /// [subtitle] - Optional subtitle message (defaults based on context)
  ///
  /// Shows the dialog without waiting for it to be dismissed.
  /// Call `dismiss(context)` to close the dialog.
  static void show(
    BuildContext context, {
    required String message,
    String? subtitle,
    IconData? icon,
  }) {
    showGeneralDialog(
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
                child: _LoadingDialog(message: message, subtitle: subtitle),
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
  /// [subtitle] - Optional subtitle message
  ///
  /// Returns the result of the operation or null if an error occurs.
  static Future<T?> showWhile<T>(
    BuildContext context, {
    required String message,
    required Future<T> Function() operation,
    String? subtitle,
  }) async {
    try {
      if (context.mounted) {
        show(context, message: message, subtitle: subtitle);
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

/// Internal loading dialog widget with pulsing animation
class _LoadingDialog extends StatefulWidget {
  final String message;
  final String? subtitle;

  const _LoadingDialog({required this.message, this.subtitle});

  @override
  State<_LoadingDialog> createState() => _LoadingDialogState();
}

class _LoadingDialogState extends State<_LoadingDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.96,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      type: MaterialType.transparency,
      child: ScaleTransition(
        scale: _pulse,
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal:
                AppBreakpoints.isDesktop(context)
                    ? 32
                    : AppBreakpoints.isTablet(context)
                    ? 28
                    : 24,
          ),
          padding: EdgeInsets.symmetric(
            horizontal:
                AppBreakpoints.isDesktop(context)
                    ? 28
                    : AppBreakpoints.isTablet(context)
                    ? 24
                    : 20,
            vertical:
                AppBreakpoints.isDesktop(context)
                    ? 28
                    : AppBreakpoints.isTablet(context)
                    ? 24
                    : 20,
          ),
          constraints: BoxConstraints(
            maxWidth:
                AppBreakpoints.isDesktop(context)
                    ? 440
                    : AppBreakpoints.isTablet(context)
                    ? 400
                    : 360,
          ),
          decoration: BoxDecoration(
            color:
                theme.brightness == Brightness.dark
                    ? cs.surfaceContainerHigh.withValues(alpha: 0.9)
                    : cs.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(
              AppBreakpoints.isDesktop(context)
                  ? 24
                  : AppBreakpoints.isTablet(context)
                  ? 22
                  : 20,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius:
                    AppBreakpoints.isDesktop(context)
                        ? 32
                        : AppBreakpoints.isTablet(context)
                        ? 28
                        : 24,
                offset: Offset(
                  0,
                  AppBreakpoints.isDesktop(context)
                      ? 16
                      : AppBreakpoints.isTablet(context)
                      ? 14
                      : 12,
                ),
              ),
            ],
            border: Border.all(
              color: cs.primary.withValues(alpha: 0.12),
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Circular progress indicator
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Animated title with dots
              _AnimatedDotsTitle(title: widget.message),

              const SizedBox(height: 10),

              // Subtitle
              Text(
                widget.subtitle ?? _getDefaultSubtitle(widget.message),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),

              const SizedBox(height: 16),

              // Linear progress indicator
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  backgroundColor: cs.primary.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDefaultSubtitle(String message) {
    if (message.contains('Import')) {
      return 'Magic is happening... Your recipe will be ready soon!';
    } else if (message.contains('Generat')) {
      return 'Whisking ideas, simmering flavors, and plating suggestions...';
    }
    return 'Please wait...';
  }
}

/// Animated title that shows dots appearing one by one
class _AnimatedDotsTitle extends StatefulWidget {
  final String title;

  const _AnimatedDotsTitle({required this.title});

  @override
  State<_AnimatedDotsTitle> createState() => _AnimatedDotsTitleState();
}

class _AnimatedDotsTitleState extends State<_AnimatedDotsTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = (_controller.value * 3).floor();
        final dots = ''.padRight((t % 3) + 1, '.');
        return Text(
          '${widget.title}$dots',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        );
      },
    );
  }
}
