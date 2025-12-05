import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';
import '../services/local_storage_service.dart';
import '../theme/theme.dart';

/// Indicator showing cached data status and last sync time
class CacheStatusIndicator extends StatelessWidget {
  final String dataType; // 'recipes', 'collections', 'discover'
  final bool compact;

  const CacheStatusIndicator({
    super.key,
    required this.dataType,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DateTime?>(
      future: LocalStorageService().getLastSyncTime(dataType),
      builder: (context, snapshot) {
        final connectivity = Provider.of<ConnectivityProvider>(context);
        final lastSync = snapshot.data;
        final isOffline = connectivity.isOffline;

        // Show offline indicator
        if (isOffline) {
          return _buildOfflineIndicator(context, compact);
        }

        // Always show sync indicator (default to showing last sync)
        return _buildSyncIndicator(context, lastSync, compact);
      },
    );
  }

  Widget _buildOfflineIndicator(BuildContext context, bool compact) {
    if (compact) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.responsive(
            context,
            mobile: 8,
            tablet: 10,
            desktop: 12,
          ),
          vertical: AppSpacing.responsive(
            context,
            mobile: 4,
            tablet: 5,
            desktop: 6,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: AppSizing.responsiveIconSize(
                context,
                mobile: 14,
                tablet: 16,
                desktop: 18,
              ),
              color: Theme.of(context).colorScheme.error,
            ),
            SizedBox(
              width: AppSpacing.responsive(
                context,
                mobile: 4,
                tablet: 5,
                desktop: 6,
              ),
            ),
            Text(
              'Offline',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.responsive(context),
        vertical: AppSpacing.responsive(
          context,
          mobile: 6,
          tablet: 8,
          desktop: 10,
        ),
      ),
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.responsive(context),
        vertical: AppSpacing.responsive(
          context,
          mobile: 4,
          tablet: 5,
          desktop: 6,
        ),
      ),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: AppSizing.responsiveIconSize(
              context,
              mobile: 16,
              tablet: 18,
              desktop: 20,
            ),
            color: Theme.of(context).colorScheme.error,
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
              'Showing cached data. You\'re offline.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncIndicator(
    BuildContext context,
    DateTime? lastSync,
    bool compact,
  ) {
    String timeText;

    if (lastSync == null) {
      timeText = 'Never synced';
    } else {
      final now = DateTime.now();
      final difference = now.difference(lastSync);

      if (difference.inMinutes < 1) {
        timeText = 'Just now';
      } else if (difference.inMinutes < 60) {
        timeText = '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        timeText = '${difference.inHours}h ago';
      } else {
        timeText = '${difference.inDays}d ago';
      }
    }

    if (compact) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.responsive(
            context,
            mobile: 8,
            tablet: 10,
            desktop: 12,
          ),
          vertical: AppSpacing.responsive(
            context,
            mobile: 4,
            tablet: 5,
            desktop: 6,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_done_rounded,
              size: AppSizing.responsiveIconSize(
                context,
                mobile: 14,
                tablet: 16,
                desktop: 18,
              ),
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(
              width: AppSpacing.responsive(
                context,
                mobile: 4,
                tablet: 5,
                desktop: 6,
              ),
            ),
            Text(
              lastSync == null ? timeText : 'Synced $timeText',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.responsive(context),
        vertical: AppSpacing.responsive(
          context,
          mobile: 6,
          tablet: 8,
          desktop: 10,
        ),
      ),
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.responsive(context),
        vertical: AppSpacing.responsive(
          context,
          mobile: 4,
          tablet: 5,
          desktop: 6,
        ),
      ),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_done_rounded,
            size: AppSizing.responsiveIconSize(
              context,
              mobile: 16,
              tablet: 18,
              desktop: 20,
            ),
            color: Theme.of(context).colorScheme.primary,
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
              lastSync == null ? 'Never synced' : 'Last synced: $timeText',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
