import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../components/credits_badge.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/dynamic_banner.dart';
import '../providers/dynamic_ui_provider.dart';
import '../providers/subscription_provider.dart';
import '../models/purchase_product.dart';
import '../components/error_display.dart';
import '../theme/theme.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Duration _trialRemaining = Duration.zero;
  Timer? _trialTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    // Start a ticking timer to update the trial countdown if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startTrialTicker();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _trialTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        elevation: AppElevation.appBar,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: colorScheme.onSurface,
        actions: const [CreditsPill()],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colorScheme.onPrimary,
          labelColor: colorScheme.onPrimary,
          unselectedLabelColor: colorScheme.onPrimary.withValues(alpha: 0.6),
          tabs: const [
            Tab(text: 'Subscriptions'),
            Tab(text: 'Bundles'),
            Tab(text: 'Credits'),
          ],
        ),
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

          return Column(
            children: [
              // Trial countdown banner (only during trial)
              _buildTrialCountdownBanner(context, subscriptionProvider),
              // Credits Display
              _tabController.index == 2
                  ? _buildCreditsHeader(context, subscriptionProvider)
                  : const SizedBox.shrink(),

              // Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Subscriptions Tab
                    _buildSubscriptionsTab(context, subscriptionProvider),

                    // Bundles Tab
                    _buildBundlesTab(context, subscriptionProvider),

                    // Credits Tab
                    _buildCreditsTab(context, subscriptionProvider),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: GestureDetector(
                  onTap: () async {
                    final url = Uri.parse(
                      'https://www.recipease.kitchen/fair-use',
                    );
                    if (await canLaunchUrl(url)) {
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Fair‑use policy',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _startTrialTicker() {
    _trialTimer?.cancel();
    _trialTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final provider = context.read<SubscriptionProvider>();
      final end = provider.trialEndAt;
      if (provider.trialActive && end != null) {
        final diff = end.difference(DateTime.now());
        if (mounted) {
          setState(() {
            _trialRemaining = diff.isNegative ? Duration.zero : diff;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _trialRemaining = Duration.zero;
          });
        }
      }
    });
  }

  Widget _buildTrialCountdownBanner(
    BuildContext context,
    SubscriptionProvider provider,
  ) {
    if (!provider.trialActive || provider.trialEndAt == null) {
      return const SizedBox.shrink();
    }

    final remaining = _trialRemaining;
    if (remaining <= Duration.zero) return const SizedBox.shrink();

    String two(int n) => n.toString().padLeft(2, '0');
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    final mins = remaining.inMinutes % 60;
    final secs = remaining.inSeconds % 60;
    final countdown =
        days > 0
            ? '$days d ${two(hours)}:${two(mins)}:${two(secs)}'
            : '${two(hours)}:${two(mins)}:${two(secs)}';

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.rocket_launch,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trial ends in $countdown',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Subscribe now to unlock full monthly credits when your trial ends.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _tabController.animateTo(0),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.onPrimary,
              foregroundColor: cs.primary,
            ),
            child: const Text('Subscribe'),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditsHeader(
    BuildContext context,
    SubscriptionProvider provider,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final credits = provider.credits;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildCreditBadge(
            context,
            icon: Icons.share,
            label: 'Imports',
            count: credits['recipeImports'] ?? 0,
          ),
          _buildCreditBadge(
            context,
            icon: Icons.auto_awesome_rounded,
            label: 'Generations',
            count: credits['recipeGenerations'] ?? 0,
          ),
          if (provider.isPremium)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    'Premium',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCreditBadge(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int count,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, size: 24),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _buildSubscriptionsTab(
    BuildContext context,
    SubscriptionProvider provider,
  ) {
    final subscriptions = provider.subscriptions;

    if (subscriptions.isEmpty) {
      return const Center(child: Text('No subscriptions available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dynamic UI banners (shop_top)
          Consumer<DynamicUiProvider>(
            builder: (context, dyn, _) {
              final banners = dyn.bannersForPlacement('shop_top');
              if (banners.isEmpty) return const SizedBox.shrink();
              return Column(
                children: banners.map((b) => DynamicBanner(banner: b)).toList(),
              );
            },
          ),
          // Free Trial Highlight Banner
          _buildFreeTrialBanner(context),
          const SizedBox(height: 24),

          Text(
            'Subscribe for the best value',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Get ad-free experience and monthly credits',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          ...subscriptions.map(
            (product) => _buildProductCard(
              context,
              product: product,
              onTap: () => _purchaseProduct(context, provider, product),
            ),
          ),
          const SizedBox(height: 16),

          // Trial Terms
          _buildTrialTerms(context),

          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: provider.restorePurchases,
              child: const Text('Restore Purchases'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBundlesTab(BuildContext context, SubscriptionProvider provider) {
    final bundles = provider.nonConsumables;

    if (bundles.isEmpty) {
      return const Center(child: Text('No bundles available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'One-time purchases',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Remove ads forever or get ad-free + credits bundles',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          ...bundles.map(
            (product) => _buildProductCard(
              context,
              product: product,
              onTap: () => _purchaseProduct(context, provider, product),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditsTab(BuildContext context, SubscriptionProvider provider) {
    final credits = provider.consumables;

    if (credits.isEmpty) {
      return const Center(child: Text('No credit packs available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Buy Credits',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Purchase credits for imports and recipe generation',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          ...credits.map(
            (product) => _buildProductCard(
              context,
              product: product,
              onTap: () => _purchaseProduct(context, provider, product),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _purchaseProduct(
    BuildContext context,
    SubscriptionProvider provider,
    PurchaseProduct product,
  ) async {
    // Check if it's a subscription
    final isSubscription = product.purchaseType == PurchaseType.subscription;
    final trialEligible = provider.eligibleForTrial;

    // Show confirmation dialog with trial info
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              isSubscription
                  ? (trialEligible
                      ? 'Start Free Trial'
                      : 'Confirm Subscription')
                  : 'Confirm Purchase',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isSubscription && trialEligible) ...[
                  Row(
                    children: [
                      Icon(Icons.celebration, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '7 Days FREE!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Start your free trial today. No payment required for 7 days.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'After trial: ${product.price}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trial includes:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '• Full access to all premium features\n• No ads\n• All monthly credits\n• Cancel anytime',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ] else if (isSubscription && !trialEligible) ...[
                  Text('Subscribe to ${product.title}?'),
                  const SizedBox(height: 8),
                  Text(
                    'Trial already used on this account.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ] else ...[
                  Text('Purchase ${product.title} for ${product.price}?'),
                  const SizedBox(height: 8),
                  Text(
                    'This is a one-time purchase.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isSubscription && trialEligible ? Colors.green : null,
                ),
                child: Text(
                  isSubscription
                      ? (trialEligible ? 'Start Free Trial' : 'Subscribe')
                      : 'Buy',
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await provider.purchase(product);

      if (context.mounted && provider.error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isSubscription
                  ? 'Free trial started! Enjoy 7 days of premium.'
                  : 'Purchase successful!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else if (context.mounted && provider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase failed: ${provider.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildProductCard(
    BuildContext context, {
    required PurchaseProduct product,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSubscription = product.purchaseType == PurchaseType.subscription;
    final subscriptionProvider = Provider.of<SubscriptionProvider>(
      context,
      listen: false,
    );
    final bool trialEligible = subscriptionProvider.eligibleForTrial;
    final bool isUnlimited =
        product.productType == ProductType.unlimitedPremium ||
        product.productType == ProductType.unlimitedPremiumYearly ||
        product.unlimitedUsage;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: product.isBestValue ? 4 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border:
                product.isBestValue
                    ? Border.all(color: Colors.green, width: 2)
                    : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Product Icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        product.icon,
                        color: colorScheme.onPrimaryContainer,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (product.unlimitedUsage) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.purple,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.all_inclusive,
                                    size: 14,
                                    color: Colors.purple,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Unlimited',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.purple,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                    if (product.isBestValue)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'BEST VALUE',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),

                // Free Trial Badge for subscriptions (only when eligible)
                if (isSubscription && trialEligible && !isUnlimited) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.celebration, size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          '7 Days FREE Trial',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 8),
                Text(
                  product.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (product.includesAdFree) ...[
                      const Icon(Icons.block, size: 16),
                      const SizedBox(width: 4),
                      const Text('Ad-Free'),
                      const SizedBox(width: 12),
                    ],
                    if (product.creditAmount != null) ...[
                      const Icon(Icons.star, size: 16),
                      const SizedBox(width: 4),
                      Text('${product.creditAmount} Credits'),
                      const SizedBox(width: 12),
                    ],
                    if (product.monthlyCredits != null) ...[
                      const Icon(Icons.autorenew, size: 16),
                      const SizedBox(width: 4),
                      Text('${product.monthlyCredits} Credits/month'),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isSubscription && trialEligible && !isUnlimited)
                          Text(
                            'Then ${product.price}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        Text(
                          isSubscription
                              ? (trialEligible && !isUnlimited
                                  ? 'FREE for 7 days'
                                  : product.price)
                              : product.price,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color:
                                isSubscription && trialEligible && !isUnlimited
                                    ? Colors.green
                                    : colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (product.productType ==
                            ProductType.unlimitedPremiumYearly) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Equivalent to \$9.99/month',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                    ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isSubscription && trialEligible && !isUnlimited
                                ? Colors.green
                                : colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        isSubscription
                            ? (trialEligible && !isUnlimited
                                ? 'Start Trial'
                                : 'Subscribe')
                            : 'Buy',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFreeTrialBanner(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.celebration, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Try Premium FREE',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '7 days on us • No payment required • Cancel anytime',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialTerms(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                'Free Trial Terms',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Start your 7-day free trial today\n'
            '• Full access to all premium features\n'
            '• Cancel anytime during the trial\n'
            '• No charge if you cancel before trial ends\n'
            '• Auto-renews after trial period',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
