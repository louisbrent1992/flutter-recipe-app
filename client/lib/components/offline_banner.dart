import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';
import '../theme/theme.dart';

/// Persistent banner that shows when device is offline
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityProvider>(
      builder: (context, connectivity, _) {
        // Only show when offline
        if (connectivity.isOnline) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.responsive(context),
            vertical: AppSpacing.responsive(context, mobile: 8, tablet: 10, desktop: 12),
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
                SizedBox(width: AppSpacing.responsive(context, mobile: 8, tablet: 10, desktop: 12)),
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
        );
      },
    );
  }
}

