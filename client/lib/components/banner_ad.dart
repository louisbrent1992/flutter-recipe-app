import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_helper.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../services/tutorial_service.dart';
import '../main.dart'; // Import to access the debug flag

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  BannerAdWidgetState createState() => BannerAdWidgetState();
}

class BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  bool _showCloseButton = false;
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    // Only load ads if not in screenshot mode and tutorial is completed
    if (!hideAds) {
      _checkTutorialAndLoadAd();
    }
  }

  StreamSubscription<GlobalKey>? _tutorialSubscription;

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

  @override
  void dispose() {
    _tutorialSubscription?.cancel();
    _bannerAd?.dispose();
    _closeTimer?.cancel();
    super.dispose();
  }

  void _loadAd() {
    if (_retryCount >= _maxRetries) {
      debugPrint('Max retry attempts reached for banner ad');
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
            _showCloseButton = false;
          });
          // Reveal the close button after a 15-second delay
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
          debugPrint('Ad failed to load: $error');
          ad.dispose();
          setState(() {
            _isAdLoaded = false;
            _retryCount++;
            _showCloseButton = false;
            _bannerAd = null; // Clear the ad reference
          });

          // Only retry if we haven't exceeded max retries
          if (_retryCount < _maxRetries) {
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted && _retryCount < _maxRetries) {
                _loadAd();
              }
            });
          } else {
            debugPrint('Banner ad disabled after $_maxRetries failed attempts');
          }
        },
      ),
    );

    _bannerAd?.load();
  }

  void _navigateToSubscription() {
    Navigator.pushNamed(context, '/subscription');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, subscriptionProvider, _) {
        // Hide ads if user is premium or if debug flag is set
        if (hideAds || subscriptionProvider.isPremium) {
          return const SizedBox.shrink();
        }

        // Don't render anything if ad isn't loaded - prevents blocking touches
        if (!_isAdLoaded || _bannerAd == null) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Stack(
              children: [
                Container(
                  alignment: Alignment.center,
                  width: double.infinity,
                  height: _bannerAd!.size.height.toDouble(),
                  color: Colors.transparent,
                  child: Center(
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: AdWidget(ad: _bannerAd!),
                    ),
                  ),
                ),
                if (_showCloseButton)
                  Positioned(
                    top: 0,
                    right: 10,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _navigateToSubscription,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.close,
                            size: 8,
                            color: Theme.of(context).colorScheme.surface,
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
