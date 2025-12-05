import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';
import '../theme/theme.dart';

/// Persistent banner that shows when device is offline
/// Uses debouncing to prevent flashing during brief connectivity changes
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner>
    with SingleTickerProviderStateMixin {
  Timer? _debounceTimer;
  bool _showBanner = false;
  bool _lastOnlineState = true; // Assume online initially
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _handleConnectivityChange(bool isOnline) {
    // Only handle if state actually changed
    if (_lastOnlineState == isOnline) return;
    _lastOnlineState = isOnline;

    // Cancel any existing timer
    _debounceTimer?.cancel();

    if (isOnline) {
      // When going online, hide immediately (no delay)
      if (_showBanner) {
        _fadeController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _showBanner = false;
            });
          }
        });
      }
    } else {
      // When going offline, wait 500ms before showing (debounce)
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _showBanner = true;
          });
          _fadeController.forward();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityProvider>(
      builder: (context, connectivity, _) {
        // Handle connectivity changes with debouncing
        _handleConnectivityChange(connectivity.isOnline);

        // Don't show banner if online or not yet debounced
        if (connectivity.isOnline || !_showBanner) {
          return const SizedBox.shrink();
        }

        return FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.responsive(context),
              vertical: AppSpacing.responsive(
                context,
                mobile: 8,
                tablet: 10,
                desktop: 12,
              ),
            ),
            color: Theme.of(context).colorScheme.error,
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    color: Theme.of(context).colorScheme.onError,
                    size: AppSizing.responsiveIconSize(
                      context,
                      mobile: 18,
                      tablet: 20,
                      desktop: 22,
                    ),
                  ),
                  SizedBox(
                    width: AppSpacing.responsive(
                      context,
                      mobile: 8,
                      tablet: 10,
                      desktop: 12,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'You\'re offline. Some features may be limited.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onError,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

