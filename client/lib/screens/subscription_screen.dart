import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../models/purchase_product.dart';
import '../services/credits_service.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
              // Credits Display
              _buildCreditsHeader(context, subscriptionProvider),

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
            ],
          );
        },
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
            icon: Icons.ios_share_rounded,
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
            'Purchase credits for imports and AI recipe generation',
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
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Confirm Purchase'),
            content: Text('Purchase ${product.title} for ${product.price}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Buy'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await provider.purchase(product);

      if (context.mounted && provider.error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase successful!'),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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
                  Text(
                    product.price,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                    child: const Text('Buy'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
