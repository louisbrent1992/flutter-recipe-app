import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../theme/theme.dart';

/// Small, reusable widgets to display the user's current credit balances.
/// - [CreditsHeader] is a larger header-style row (used in screens).
/// - [CreditsPill] is a compact single-line pill (good for app bars).
class CreditsHeader extends StatelessWidget {
  const CreditsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<SubscriptionProvider>(
      builder: (context, provider, _) {
        final credits = provider.credits;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primaryContainer,
                colorScheme.secondaryContainer,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _creditBadge(
                context,
                icon: Icons.share,
                label: 'Imports',
                count: credits['recipeImports'] ?? 0,
                unlimited: provider.unlimitedUsage,
              ),
              _creditBadge(
                context,
                icon: Icons.auto_awesome_rounded,
                label: 'Generations',
                count: credits['recipeGenerations'] ?? 0,
                unlimited: provider.unlimitedUsage,
              ),
              if (provider.isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.star, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Premium',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _creditBadge(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int count,
    bool unlimited = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        if (unlimited) ...[
          const Icon(Icons.all_inclusive, size: 20, color: Colors.purple),
          const SizedBox(height: 2),
          Text(
            'Unlimited',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
        ] else ...[
          Icon(icon, size: 20),
          const SizedBox(height: 2),
          Text(
            '$count',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// Compact single-line pill for showing credits in an app bar action area.
class CreditsPill extends StatelessWidget {
  final VoidCallback? onTap;
  const CreditsPill({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, provider, _) {
        final imports = provider.credits['recipeImports'] ?? 0;
        final gens = provider.credits['recipeGenerations'] ?? 0;
        final theme = Theme.of(context);
        final isDesktop = AppBreakpoints.isDesktop(context);
        final isTablet = AppBreakpoints.isTablet(context);
        
        return Padding(
          padding: EdgeInsets.all(isDesktop ? 6.0 : isTablet ? 5.0 : 4.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(
              isDesktop ? 20 : isTablet ? 18 : 16,
            ),
            onTap: onTap,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 14 : isTablet ? 12 : 10,
                vertical: isDesktop ? 8 : isTablet ? 7 : 6,
              ),
              margin: EdgeInsets.only(
                right: isDesktop ? 12 : isTablet ? 10 : 8,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(
                  alpha: theme.colorScheme.alphaHigh,
                ),
                borderRadius: BorderRadius.circular(
                  isDesktop ? 20 : isTablet ? 18 : 16,
                ),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(
                    alpha: theme.colorScheme.overlayLight,
                  ),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(
                      alpha: theme.colorScheme.shadowLight,
                    ),
                    blurRadius: isDesktop ? 12 : isTablet ? 10 : 8,
                    offset: Offset(0, isDesktop ? 3 : isTablet ? 2.5 : 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (provider.unlimitedUsage) ...[
                    Icon(
                      Icons.all_inclusive,
                      size: isDesktop ? 20 : isTablet ? 18 : 16,
                      color: Colors.purple,
                    ),
                    SizedBox(width: isDesktop ? 8 : isTablet ? 7 : 6),
                    Text(
                      'Unlimited',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                        fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
                      ),
                    ),
                    // For unlimited, do not show numeric balances
                  ] else if (provider.trialActive) ...[
                    Icon(
                      Icons.rocket_launch,
                      size: isDesktop ? 18 : isTablet ? 16 : 14,
                      color: Colors.blue,
                    ),
                    SizedBox(width: isDesktop ? 6 : isTablet ? 5 : 4),
                    Text(
                      'Trial',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
                      ),
                    ),
                    SizedBox(width: isDesktop ? 10 : isTablet ? 9 : 8),
                  ] else if (provider.isPremium) ...[
                    Icon(
                      Icons.star,
                      size: isDesktop ? 18 : isTablet ? 16 : 14,
                      color: Colors.amber,
                    ),
                    SizedBox(width: isDesktop ? 6 : isTablet ? 5 : 4),
                    Text(
                      'Premium',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade700,
                        fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
                      ),
                    ),
                    SizedBox(width: isDesktop ? 10 : isTablet ? 9 : 8),
                  ] else ...[
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 8 : isTablet ? 7 : 6,
                        vertical: isDesktop ? 3 : isTablet ? 2.5 : 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: theme.colorScheme.overlayMedium,
                        ),
                        borderRadius: BorderRadius.circular(
                          isDesktop ? 12 : isTablet ? 11 : 10,
                        ),
                      ),
                      child: Text(
                        'Free',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: isDesktop ? 13 : isTablet ? 12 : 11,
                        ),
                      ),
                    ),
                    SizedBox(width: isDesktop ? 10 : isTablet ? 9 : 8),
                  ],
                  if (!provider.unlimitedUsage) ...[
                    Icon(
                      Icons.share,
                      size: isDesktop ? 18 : isTablet ? 16 : 14,
                    ),
                    SizedBox(width: isDesktop ? 6 : isTablet ? 5 : 4),
                    Text(
                      '$imports',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontSize: isDesktop ? 15 : isTablet ? 14 : 13,
                      ),
                    ),
                    SizedBox(width: isDesktop ? 10 : isTablet ? 9 : 8),
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: isDesktop ? 18 : isTablet ? 16 : 14,
                    ),
                    SizedBox(width: isDesktop ? 6 : isTablet ? 5 : 4),
                    Text(
                      '$gens',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontSize: isDesktop ? 15 : isTablet ? 14 : 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
