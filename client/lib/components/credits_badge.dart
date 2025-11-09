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
        return Padding(
          padding: const EdgeInsets.all(4.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(
                  alpha: theme.colorScheme.alphaHigh,
                ),
                borderRadius: BorderRadius.circular(16),
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
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (provider.unlimitedUsage) ...[
                    const Icon(
                      Icons.all_inclusive,
                      size: 16,
                      color: Colors.purple,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Unlimited',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                    // For unlimited, do not show numeric balances
                  ] else if (provider.trialActive) ...[
                    const Icon(
                      Icons.rocket_launch,
                      size: 14,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Trial',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else if (provider.isPremium) ...[
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      'Premium',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: theme.colorScheme.overlayMedium,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Free',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (!provider.unlimitedUsage) ...[
                    const Icon(Icons.share, size: 14),
                    const SizedBox(width: 4),
                    Text('$imports', style: theme.textTheme.labelMedium),
                    const SizedBox(width: 8),
                    const Icon(Icons.auto_awesome_rounded, size: 14),
                    const SizedBox(width: 4),
                    Text('$gens', style: theme.textTheme.labelMedium),
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
