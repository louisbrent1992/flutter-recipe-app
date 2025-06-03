import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../providers/subscription_provider.dart';
import '../components/error_display.dart';
import '../theme/theme.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium Subscription'),
        elevation: AppElevation.appBar,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: colorScheme.onSurface,
      ),
      body: Consumer<SubscriptionProvider>(
        builder: (context, subscriptionProvider, _) {
          if (subscriptionProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (subscriptionProvider.error != null) {
            return ErrorDisplay(
              message: subscriptionProvider.error!,
              isNetworkError:
                  subscriptionProvider.error!.toLowerCase().contains(
                    'network',
                  ) ||
                  subscriptionProvider.error!.toLowerCase().contains(
                    'connection',
                  ),
              isAuthError:
                  subscriptionProvider.error!.toLowerCase().contains('auth') ||
                  subscriptionProvider.error!.toLowerCase().contains('login'),
              isFormatError:
                  subscriptionProvider.error!.toLowerCase().contains(
                    'format',
                  ) ||
                  subscriptionProvider.error!.toLowerCase().contains('parse'),
              onRetry: () {
                subscriptionProvider.reinitialize();
              },
            );
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Premium Features Header
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 64,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Upgrade to Premium',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Unlock all features and enjoy an ad-free experience',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Premium Features List
                  Text(
                    'Premium Features',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureItem(
                    context,
                    icon: Icons.block_flipped,
                    title: 'Ad-Free Experience',
                    description: 'Enjoy your recipes without any interruptions',
                  ),
                  _buildFeatureItem(
                    context,
                    icon: Icons.restaurant_menu,
                    title: 'Exclusive Recipes',
                    description: 'Access to premium and exclusive recipes',
                  ),
                  _buildFeatureItem(
                    context,
                    icon: Icons.download_rounded,
                    title: 'Offline Access',
                    description: 'Download recipes for offline use',
                  ),
                  _buildFeatureItem(
                    context,
                    icon: Icons.analytics_rounded,
                    title: 'Advanced Analytics',
                    description: 'Track your cooking progress and preferences',
                  ),

                  const SizedBox(height: 32),

                  // Subscription Options
                  Text(
                    'Choose Your Plan',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...subscriptionProvider.products.map((product) {
                    return _buildSubscriptionOption(
                      context,
                      product: product,
                      onTap: () => subscriptionProvider.purchase(product),
                    );
                  }),

                  const SizedBox(height: 16),

                  // Restore Purchases Button
                  Center(
                    child: TextButton(
                      onPressed: subscriptionProvider.restorePurchases,
                      child: const Text('Restore Purchases'),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Terms and Privacy
                  Center(
                    child: Text(
                      'By subscribing, you agree to our Terms of Service and Privacy Policy',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.responsive(context)),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(
              AppSpacing.responsive(
                context,
                mobile: AppSpacing.sm,
                tablet: AppSpacing.md,
                desktop: AppSpacing.lg,
              ),
            ),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(
                AppBreakpoints.isMobile(context) ? 8 : 12,
              ),
            ),
            child: Icon(
              icon,
              color: colorScheme.primary,
              size: AppSizing.responsiveIconSize(context),
            ),
          ),
          SizedBox(width: AppSpacing.responsive(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: AppTypography.responsiveFontSize(context),
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: AppTypography.responsiveCaptionSize(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionOption(
    BuildContext context, {
    required ProductDetails product,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: AppSpacing.responsive(
          context,
          mobile: AppSpacing.sm,
          tablet: AppSpacing.md,
          desktop: AppSpacing.lg,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(
            AppBreakpoints.isMobile(context) ? 8 : 12,
          ),
          onTap: onTap,
          child: Container(
            padding: AppSizing.responsiveCardPadding(context),
            decoration: BoxDecoration(
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.2),
              ),
              borderRadius: BorderRadius.circular(
                AppBreakpoints.isMobile(context) ? 8 : 12,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: AppTypography.responsiveFontSize(context),
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        product.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: AppTypography.responsiveCaptionSize(
                            context,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.responsive(context)),
                Text(
                  product.price,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: AppTypography.responsiveFontSize(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
