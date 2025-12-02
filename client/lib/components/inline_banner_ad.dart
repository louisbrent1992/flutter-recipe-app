import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_helper.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../services/tutorial_service.dart';
import '../main.dart';
import '../theme/theme.dart';

class InlineBannerAd extends StatefulWidget {
  const InlineBannerAd({super.key});

  @override
  State<InlineBannerAd> createState() => _InlineBannerAdState();
}

class _InlineBannerAdState extends State<InlineBannerAd> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  StreamSubscription<GlobalKey>? _tutorialSubscription;
  bool _showCloseButton = false;
  Timer? _closeTimer;

  // Keep track of the loaded size to update the container height dynamically
  AdSize? _adSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // We load the ad here to ensure we can access MediaQuery for the correct width
    // Skip loading entirely if user is premium or ads are hidden
    final subscriptionProvider = context.read<SubscriptionProvider>();
    if (!_isAdLoaded && _bannerAd == null && !hideAds && !subscriptionProvider.isPremium) {
      _checkTutorialAndLoadAd();
    }
  }

  Future<void> _checkTutorialAndLoadAd() async {
    // Double-check premium status before loading
    if (!mounted) return;
    final subscriptionProvider = context.read<SubscriptionProvider>();
    if (subscriptionProvider.isPremium) return;
    
    final tutorialService = TutorialService();
    final isCompleted = await tutorialService.isTutorialCompleted();

    if (isCompleted && mounted) {
      _loadAd();
    } else {
      _tutorialSubscription?.cancel();
      _tutorialSubscription = tutorialService.onStepChanged.listen((_) async {
        final completed = await tutorialService.isTutorialCompleted();
        if (completed && mounted && !_isAdLoaded) {
          _loadAd();
          _tutorialSubscription?.cancel();
        }
      });
    }
  }

  Future<void> _loadAd() async {
    if (_retryCount >= _maxRetries || !mounted) return;
    
    // Skip ad loading for premium users
    final subscriptionProvider = context.read<SubscriptionProvider>();
    if (subscriptionProvider.isPremium) return;

    // 1. Calculate the available width for the ad
    // This ensures the ad expands to the edges of your content area
    final horizontalPadding = AppSpacing.responsive(
      context,
      mobile: AppSpacing.md,
      tablet: AppSpacing.lg,
      desktop: AppSpacing.xl,
    );

    // Get screen width minus the padding used by your app
    final double adWidth =
        MediaQuery.of(context).size.width - (horizontalPadding * 2);

    // 2. Get the Adaptive Ad Size
    final AdSize adaptiveSize =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
          adWidth.truncate(), // Width must be an integer
        ) ??
        AdSize.banner;

    _bannerAd = BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      size: adaptiveSize, // Use the calculated adaptive size
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isAdLoaded = true;
            _retryCount = 0;
            _adSize = adaptiveSize; // Save the size to use in the build method
            _showCloseButton = false;
          });
          // Show close button after 10 seconds
          _closeTimer?.cancel();
          _closeTimer = Timer(const Duration(seconds: 10), () {
            if (mounted) {
              setState(() {
                _showCloseButton = true;
              });
            }
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Inline ad failed to load: $error');
          ad.dispose();
          setState(() {
            _isAdLoaded = false;
            _retryCount++;
          });
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) _loadAd();
          });
        },
      ),
    );

    _bannerAd?.load();
  }

  @override
  void dispose() {
    _tutorialSubscription?.cancel();
    _closeTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  void _navigateToSubscription() {
    Navigator.pushNamed(context, '/subscription');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, subscriptionProvider, _) {
        if (hideAds || subscriptionProvider.isPremium) {
          return const SizedBox.shrink();
        }

        if (!_isAdLoaded || _bannerAd == null || _adSize == null) {
          return const SizedBox.shrink();
        }

        // 3. Simplified Layout
        // No LayoutBuilder or Transform needed.
        // We simply let the container fill the parent width.
        final double adHeight = _adSize!.height.toDouble();

        return SizedBox(
          height: adHeight + 32, // Height + Margins
          width: double.infinity,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              // Width matches the ad size (which we calculated to match the content)
              width: _adSize!.width.toDouble(),
              height: adHeight,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: _adSize!.width.toDouble(),
                  height: adHeight,
                  child: AdWidget(
                    key: ValueKey('ad_widget_${_bannerAd.hashCode}'),
                    ad: _bannerAd!,
                  ),
                ),
              ),
                ),
                // Close button - appears after delay
                if (_showCloseButton)
                  Positioned(
                    top: 8,
                    right: -4,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _navigateToSubscription,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
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
