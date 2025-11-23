import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:provider/provider.dart';
import '../components/custom_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/dynamic_banner.dart';
import '../providers/dynamic_ui_provider.dart';
import '../providers/subscription_provider.dart';
import '../models/purchase_product.dart';
import '../components/error_display.dart';
import '../theme/theme.dart';
import '../utils/snackbar_helper.dart';
import '../utils/error_utils.dart';
// import '../components/floating_bottom_bar.dart';

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
      appBar: CustomAppBar(
        title: 'Shop',
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colorScheme.onSurface,
          labelColor: colorScheme.onSurface,
          unselectedLabelColor: colorScheme.onSurface.withValues(alpha: 0.6),
          tabs: const [
            Tab(text: 'Subscriptions'),
            Tab(text: 'Bundles'),
            Tab(text: 'Credits'),
          ],
        ),
      ),
      body: Stack(
        children: [
          Consumer<SubscriptionProvider>(
            builder: (context, subscriptionProvider, _) {
              if (subscriptionProvider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (subscriptionProvider.error != null) {
                return ErrorDisplay(
                  message: subscriptionProvider.error!,
                  isNetworkError: ErrorUtils.isNetworkError(
                    subscriptionProvider.error!,
                  ),
                  isAuthError: ErrorUtils.isAuthError(
                    subscriptionProvider.error!,
                  ),
                  isFormatError: ErrorUtils.isFormatError(
                    subscriptionProvider.error!,
                  ),
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
                ],
              );
            },
          ),

          // Floating navigation bar
          // sconst FloatingBottomBar(),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.rocket_launch,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trial ends in $countdown',
                  style: theme.textTheme.bodyMedium?.copyWith(
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
          const SizedBox(width: 6),
          ElevatedButton(
            onPressed: () => _tabController.animateTo(0),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.onPrimary,
              foregroundColor: cs.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    final bool isUnlimited = provider.unlimitedUsage;

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
            unlimited: isUnlimited,
          ),
          _buildCreditBadge(
            context,
            icon: Icons.auto_awesome_rounded,
            label: 'Generations',
            count: credits['recipeGenerations'] ?? 0,
            unlimited: isUnlimited,
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
    required bool unlimited,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, size: 24),
        const SizedBox(height: 4),
        Text(
          unlimited ? '∞' : '$count',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
  // _buildCreditBadge removed in favor of shared CreditsHeader from credits_badge.dart

  Widget _buildSubscriptionsTab(
    BuildContext context,
    SubscriptionProvider provider,
  ) {
    final subscriptions = provider.subscriptions;

    if (subscriptions.isEmpty) {
      return const Center(child: Text('No subscriptions available'));
    }

    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth:
                AppBreakpoints.isDesktop(context)
                    ? 800
                    : AppBreakpoints.isTablet(context)
                    ? 700
                    : double.infinity,
          ),
          padding: EdgeInsets.only(
            left: AppSpacing.responsive(context),
            right: AppSpacing.responsive(context),
            top: AppSpacing.responsive(context),
            bottom: AppSpacing.responsive(context) + 30, // Extra space for floating bar
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dynamic UI banners (shop_top)
              Consumer<DynamicUiProvider>(
                builder: (context, dyn, _) {
                  final banners = dyn.bannersForPlacement('shop_top');
                  if (banners.isEmpty) return const SizedBox.shrink();
                  return Column(
                    children:
                        banners.map((b) => DynamicBanner(banner: b)).toList(),
                  );
                },
              ),
              // Free Trial Highlight Banner
              _buildFreeTrialBanner(context),
              SizedBox(
                height:
                    AppBreakpoints.isDesktop(context)
                        ? 32
                        : AppBreakpoints.isTablet(context)
                        ? 28
                        : 24,
              ),

              Text(
                'Subscribe for the best value',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: AppTypography.responsiveHeadingSize(
                    context,
                    mobile: 20,
                    tablet: 24,
                    desktop: 28,
                  ),
                ),
              ),
              SizedBox(
                height:
                    AppBreakpoints.isDesktop(context)
                        ? 12
                        : AppBreakpoints.isTablet(context)
                        ? 10
                        : 8,
              ),
              Text(
                'Get ad-free experience and monthly credits',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: AppTypography.responsiveFontSize(
                    context,
                    mobile: 14,
                    tablet: 16,
                    desktop: 18,
                  ),
                ),
              ),
              SizedBox(
                height:
                    AppBreakpoints.isDesktop(context)
                        ? 32
                        : AppBreakpoints.isTablet(context)
                        ? 28
                        : 24,
              ),
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

              SizedBox(height: AppSpacing.responsive(context)),
              Center(
                child: TextButton(
                  onPressed: provider.restorePurchases,
                  child: const Text('Restore Purchases'),
                ),
              ),
              const SizedBox(height: 80), // Extra padding for bottom bar
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBundlesTab(BuildContext context, SubscriptionProvider provider) {
    final bundles = provider.nonConsumables;

    if (bundles.isEmpty) {
      return const Center(child: Text('No bundles available'));
    }

    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth:
                AppBreakpoints.isDesktop(context)
                    ? 800
                    : AppBreakpoints.isTablet(context)
                    ? 700
                    : double.infinity,
          ),
          padding: EdgeInsets.only(
            left: AppSpacing.responsive(context),
            right: AppSpacing.responsive(context),
            top: AppSpacing.responsive(context),
            bottom: AppSpacing.responsive(context) + 30, // Extra space for floating bar
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'One-time purchases',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: AppTypography.responsiveHeadingSize(
                    context,
                    mobile: 20,
                    tablet: 24,
                    desktop: 28,
                  ),
                ),
              ),
              SizedBox(
                height:
                    AppBreakpoints.isDesktop(context)
                        ? 12
                        : AppBreakpoints.isTablet(context)
                        ? 10
                        : 8,
              ),
              Text(
                'Remove ads forever or get ad-free + credits bundles',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: AppTypography.responsiveFontSize(
                    context,
                    mobile: 14,
                    tablet: 16,
                    desktop: 18,
                  ),
                ),
              ),
              SizedBox(
                height:
                    AppBreakpoints.isDesktop(context)
                        ? 32
                        : AppBreakpoints.isTablet(context)
                        ? 28
                        : 24,
              ),
              ...bundles.map(
                (product) => _buildProductCard(
                  context,
                  product: product,
                  onTap: () => _purchaseProduct(context, provider, product),
                ),
              ),
              const SizedBox(height: 80), // Extra padding for bottom bar
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreditsTab(BuildContext context, SubscriptionProvider provider) {
    final credits = provider.consumables;

    if (credits.isEmpty) {
      return const Center(child: Text('No credit packs available'));
    }

    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth:
                AppBreakpoints.isDesktop(context)
                    ? 800
                    : AppBreakpoints.isTablet(context)
                    ? 700
                    : double.infinity,
          ),
          padding: EdgeInsets.only(
            left: AppSpacing.responsive(context),
            right: AppSpacing.responsive(context),
            top: AppSpacing.responsive(context),
            bottom: AppSpacing.responsive(context) + 30, // Extra space for floating bar
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Buy Credits',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: AppTypography.responsiveHeadingSize(
                    context,
                    mobile: 20,
                    tablet: 24,
                    desktop: 28,
                  ),
                ),
              ),
              SizedBox(
                height:
                    AppBreakpoints.isDesktop(context)
                        ? 12
                        : AppBreakpoints.isTablet(context)
                        ? 10
                        : 8,
              ),
              Text(
                'Purchase credits for imports and recipe generation',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: AppTypography.responsiveFontSize(
                    context,
                    mobile: 14,
                    tablet: 16,
                    desktop: 18,
                  ),
                ),
              ),
              SizedBox(
                height:
                    AppBreakpoints.isDesktop(context)
                        ? 32
                        : AppBreakpoints.isTablet(context)
                        ? 28
                        : 24,
              ),
              ...credits.map(
                (product) => _buildProductCard(
                  context,
                  product: product,
                  onTap: () => _purchaseProduct(context, provider, product),
                ),
              ),
              const SizedBox(height: 80), // Extra padding for bottom bar
            ],
          ),
        ),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                AppDialog.responsiveBorderRadius(context),
              ),
            ),
            title: Text(
              isSubscription
                  ? (trialEligible
                      ? 'Start Free Trial'
                      : 'Confirm Subscription')
                  : 'Confirm Purchase',
              style: TextStyle(
                fontSize: AppDialog.responsiveTitleSize(context),
              ),
            ),
            contentPadding: AppDialog.responsivePadding(context),
            content: Container(
              constraints: BoxConstraints(
                maxWidth: AppDialog.responsiveMaxWidth(context),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isSubscription && trialEligible) ...[
                    // Show subscription price prominently (Apple requirement)
                    Container(
                      padding: EdgeInsets.all(
                        AppBreakpoints.isDesktop(context)
                            ? 16
                            : AppBreakpoints.isTablet(context)
                            ? 14
                            : 12,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(
                          AppBreakpoints.isDesktop(context)
                              ? 12
                              : AppBreakpoints.isTablet(context)
                              ? 10
                              : 8,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Subscription Price',
                            style: TextStyle(
                              fontSize:
                                  AppDialog.responsiveContentSize(context) *
                                  0.875,
                              fontWeight: FontWeight.w600,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          SizedBox(
                            height:
                                AppBreakpoints.isDesktop(context)
                                    ? 8
                                    : AppBreakpoints.isTablet(context)
                                    ? 7
                                    : 6,
                          ),
                          Text(
                            product.price,
                            style: TextStyle(
                              fontSize: AppDialog.responsiveTitleSize(context),
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height:
                          AppBreakpoints.isDesktop(context)
                              ? 16
                              : AppBreakpoints.isTablet(context)
                              ? 14
                              : 12,
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.celebration,
                          color: Colors.green,
                          size: AppSizing.responsiveIconSize(
                            context,
                            mobile: 18,
                            tablet: 20,
                            desktop: 22,
                          ),
                        ),
                        SizedBox(
                          width:
                              AppBreakpoints.isDesktop(context)
                                  ? 8
                                  : AppBreakpoints.isTablet(context)
                                  ? 7
                                  : 6,
                        ),
                        Expanded(
                          child: Text(
                            '7-day free trial included',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                              fontSize:
                                  AppDialog.responsiveContentSize(context) *
                                  0.875,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      height:
                          AppBreakpoints.isDesktop(context)
                              ? 12
                              : AppBreakpoints.isTablet(context)
                              ? 10
                              : 8,
                    ),
                    Text(
                      'Start your free trial today. The subscription will begin at ${product.price} after the 7-day trial ends.',
                      style: TextStyle(
                        fontSize:
                            AppDialog.responsiveContentSize(context) * 0.875,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(
                      height:
                          AppBreakpoints.isDesktop(context)
                              ? 16
                              : AppBreakpoints.isTablet(context)
                              ? 14
                              : 12,
                    ),
                    Container(
                      padding: EdgeInsets.all(
                        AppBreakpoints.isDesktop(context)
                            ? 16
                            : AppBreakpoints.isTablet(context)
                            ? 14
                            : 12,
                      ),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(
                          AppBreakpoints.isDesktop(context)
                              ? 12
                              : AppBreakpoints.isTablet(context)
                              ? 10
                              : 8,
                        ),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'What you get:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize:
                                  AppDialog.responsiveContentSize(context) *
                                  0.875,
                            ),
                          ),
                          SizedBox(
                            height:
                                AppBreakpoints.isDesktop(context)
                                    ? 6
                                    : AppBreakpoints.isTablet(context)
                                    ? 5
                                    : 4,
                          ),
                          Text(
                            '• Full access to all premium features\n• Ad-free experience\n• All monthly credits\n• Cancel anytime during trial (no charge)',
                            style: TextStyle(
                              fontSize:
                                  AppDialog.responsiveContentSize(context) *
                                  0.875,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (isSubscription && !trialEligible) ...[
                    Text(
                      'Subscribe to ${product.title}?',
                      style: TextStyle(
                        fontSize: AppDialog.responsiveContentSize(context),
                      ),
                    ),
                    SizedBox(
                      height:
                          AppBreakpoints.isDesktop(context)
                              ? 10
                              : AppBreakpoints.isTablet(context)
                              ? 9
                              : 8,
                    ),
                    Text(
                      'Trial already used on this account.',
                      style: TextStyle(
                        fontSize:
                            AppDialog.responsiveContentSize(context) * 0.875,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Purchase ${product.title} for ${product.price}?',
                      style: TextStyle(
                        fontSize: AppDialog.responsiveContentSize(context),
                      ),
                    ),
                    SizedBox(
                      height:
                          AppBreakpoints.isDesktop(context)
                              ? 10
                              : AppBreakpoints.isTablet(context)
                              ? 9
                              : 8,
                    ),
                    Text(
                      'This is a one-time purchase.',
                      style: TextStyle(
                        fontSize:
                            AppDialog.responsiveContentSize(context) * 0.875,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actionsPadding: AppDialog.responsivePadding(context),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  padding: AppDialog.responsiveButtonPadding(context),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: AppDialog.responsiveContentSize(context),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isSubscription && trialEligible ? Colors.green : null,
                  padding: AppDialog.responsiveButtonPadding(context),
                ),
                child: Text(
                  isSubscription
                      ? (trialEligible ? 'Start Free Trial' : 'Subscribe')
                      : 'Buy',
                  style: TextStyle(
                    fontSize: AppDialog.responsiveContentSize(context),
                  ),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await provider.purchase(product);

      if (context.mounted && provider.error == null) {
        SnackBarHelper.showSuccess(
          context,
          isSubscription
              ? (trialEligible
                  ? 'Subscription started! 7-day trial begins now.'
                  : 'Subscription successful!')
              : 'Purchase successful!',
        );
      } else if (context.mounted && provider.error != null) {
        SnackBarHelper.showError(context, 'Purchase failed: ${provider.error}');
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

    return Consumer<SubscriptionProvider>(
      builder: (context, subscriptionProvider, _) {
        final bool trialEligible = subscriptionProvider.eligibleForTrial;
        final bool isSubscribed =
            isSubscription && subscriptionProvider.isProductSubscribed(product);

        final cardBorderRadius =
            AppBreakpoints.isDesktop(context)
                ? 16.0
                : AppBreakpoints.isTablet(context)
                ? 14.0
                : 12.0;

        return Card(
          margin: EdgeInsets.only(
            bottom:
                AppBreakpoints.isDesktop(context)
                    ? 16
                    : AppBreakpoints.isTablet(context)
                    ? 14
                    : 12,
          ),
          elevation: product.isBestValue ? 4 : 1,
          child: InkWell(
            onTap: isSubscribed ? null : onTap,
            borderRadius: BorderRadius.circular(cardBorderRadius),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(cardBorderRadius),
                border:
                    product.isBestValue
                        ? Border.all(color: Colors.green, width: 2)
                        : null,
              ),
              child: Padding(
                padding: EdgeInsets.all(
                  AppBreakpoints.isDesktop(context)
                      ? 20
                      : AppBreakpoints.isTablet(context)
                      ? 18
                      : 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Product Icon
                        Container(
                          padding: EdgeInsets.all(
                            AppBreakpoints.isDesktop(context)
                                ? 12
                                : AppBreakpoints.isTablet(context)
                                ? 10
                                : 8,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(
                              AppBreakpoints.isDesktop(context)
                                  ? 12
                                  : AppBreakpoints.isTablet(context)
                                  ? 10
                                  : 8,
                            ),
                          ),
                          child: Icon(
                            product.icon,
                            color: colorScheme.onPrimaryContainer,
                            size: AppSizing.responsiveIconSize(
                              context,
                              mobile: 22,
                              tablet: 26,
                              desktop: 30,
                            ),
                          ),
                        ),
                        SizedBox(
                          width:
                              AppBreakpoints.isDesktop(context)
                                  ? 16
                                  : AppBreakpoints.isTablet(context)
                                  ? 14
                                  : 12,
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  product.title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              if (product.unlimitedUsage) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withValues(
                                      alpha: 0.12,
                                    ),
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
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
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
                    if (isSubscription && trialEligible) ...[
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
                            Icon(
                              Icons.celebration,
                              size: 14,
                              color: Colors.green,
                            ),
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
                    // Display subscription details (required by App Store)
                    if (isSubscription) ...[
                      const SizedBox(height: 8),
                      _buildSubscriptionDetails(
                        context,
                        product,
                        trialEligible,
                      ),
                    ],
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
                          const SizedBox(width: 12),
                        ],
                        if (product.unlimitedUsage) ...[
                          const Icon(Icons.all_inclusive, size: 16),
                          const SizedBox(width: 4),
                          const Text('Unlimited'),
                          const SizedBox(width: 12),
                        ],
                      ],
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Always show the actual price prominently (Apple requirement)
                            Text(
                              product.price,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            // Show trial info as secondary text
                            if (product.productType ==
                                ProductType.unlimitedPremiumYearly) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Equivalent to \$6.67/month',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                        ElevatedButton(
                          onPressed: isSubscribed ? null : onTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isSubscribed
                                    ? Colors.grey
                                    : (isSubscription && trialEligible
                                        ? Colors.green
                                        : colorScheme.primary),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(
                            isSubscribed
                                ? 'Subscribed'
                                : (isSubscription
                                    ? (trialEligible
                                        ? 'Start Trial'
                                        : 'Subscribe')
                                    : 'Buy'),
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
      },
    );
  }

  Widget _buildFreeTrialBanner(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
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
            child: const Icon(Icons.star, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Premium Subscriptions',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Starting at \$6.99/month • All plans include 7-day free trial',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
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
                'Subscription Terms',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Premium Monthly: \$6.99/month with 7-day free trial\n'
            '• Premium Yearly: \$44.99/year (\$3.75/month) with 7-day free trial\n'
            '• Premium Unlimited Monthly: \$19.99/month with 7-day free trial\n'
            '• Premium Unlimited Yearly: \$79.99/year (\$6.67/month) with 7-day free trial\n'
            '• All subscriptions include 7-day free trial with unlimited usage\n'
            '• Auto-renewable subscriptions\n'
            '• Cancel anytime in Account Settings\n'
            '• No charge if cancelled during trial period\n'
            '${Platform.isIOS ? '• Payment charged to Apple ID at confirmation\n' : '• Payment charged to Google Play account at confirmation\n'}'
            '• Subscription auto-renews unless cancelled 24 hours before end of period\n'
            '• Unlimited plans subject to fair-use policy for personal use',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildTextLink(
                context,
                'Privacy Policy',
                'https://recipease.kitchen/privacy',
              ),
              _buildTextLink(
                context,
                'Terms of Use',
                Platform.isIOS
                    ? 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'
                    : 'https://play.google.com/about/play-terms/index.html',
              ),
              _buildTextLink(
                context,
                'Fair-Use Policy',
                'https://recipease.kitchen/fair-use',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextLink(BuildContext context, String text, String url) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSubscriptionDetails(
    BuildContext context,
    PurchaseProduct product,
    bool trialEligible,
  ) {
    final theme = Theme.of(context);
    String duration = '';
    String pricePerUnit = '';

    // Determine duration and price per unit
    switch (product.productType) {
      case ProductType.monthlyPremium:
        duration = '1 month';
        pricePerUnit = '\$6.99/month';
        break;
      case ProductType.yearlyPremium:
        duration = '1 year';
        pricePerUnit = '\$44.99/year (\$3.75/month)';
        break;
      case ProductType.unlimitedPremium:
        duration = '1 month';
        pricePerUnit = '\$19.99/month';
        break;
      case ProductType.unlimitedPremiumYearly:
        duration = '1 year';
        pricePerUnit = '\$79.99/year (\$6.67/month)';
        break;
      default:
        break;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Always show price first and prominently (Apple requirement)
          Row(
            children: [
              Icon(
                Icons.payments_outlined,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Price: $pricePerUnit',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Show trial information as secondary detail
          if (trialEligible) ...[
            Row(
              children: [
                Icon(Icons.celebration, size: 14, color: Colors.green),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '7-day free trial included',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text('Billed every $duration', style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.autorenew,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Auto-renews until cancelled',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
