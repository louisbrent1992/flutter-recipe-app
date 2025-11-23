import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_helper.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../services/tutorial_service.dart';
import '../main.dart'; // Import to access the debug flag

/// Inline banner ad widget for embedding within scrollable content
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

  @override
  void initState() {
    super.initState();
    // Only load ads if not in screenshot mode and tutorial is completed
    if (!hideAds) {
      _checkTutorialAndLoadAd();
    }
  }

  Future<void> _checkTutorialAndLoadAd() async {
    final tutorialService = TutorialService();
    final isCompleted = await tutorialService.isTutorialCompleted();
    
    // Only load ads after tutorial is completed
    if (isCompleted && mounted) {
      _loadAd();
    } else {
      // Listen for tutorial completion via step changes
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

  void _loadAd() {
    if (_retryCount >= _maxRetries) {
      debugPrint('Max retry attempts reached for inline banner ad');
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isAdLoaded = true;
            _retryCount = 0; // Reset retry count on successful load
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Inline ad failed to load: $error');
          ad.dispose();
          setState(() {
            _isAdLoaded = false;
            _retryCount++;
          });

          // Retry loading after a delay
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) {
              _loadAd();
            }
          });
        },
      ),
    );

    _bannerAd?.load();
  }

  @override
  void dispose() {
    _tutorialSubscription?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, subscriptionProvider, _) {
        // Hide ads if user is premium or if debug flag is set
        if (hideAds || subscriptionProvider.isPremium) {
          return const SizedBox.shrink();
        }

        if (!_isAdLoaded || _bannerAd == null) {
          return const SizedBox.shrink();
        }

        // Return inline banner as a card-style widget
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
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
              width: double.infinity,
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
          ),
        );
      },
    );
  }
}
