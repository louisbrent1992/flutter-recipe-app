import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_helper.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
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

  @override
  void initState() {
    super.initState();
    // Only load ads if not in screenshot mode
    if (!hideAds) {
      _loadAd();
    }
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
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Ad failed to load: $error');
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
    _bannerAd?.dispose();
    super.dispose();
  }

  void _navigateToSubscription() {
    Navigator.pushNamed(context, '/subscription');
  }

  @override
  Widget build(BuildContext context) {
    // Hide ads completely when debug flag is set
    if (hideAds) {
      return const SizedBox.shrink();
    }

    if (!_isAdLoaded) {
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
              height: _bannerAd?.size.height.toDouble(),
              color: Colors.transparent,
              child: Center(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: AdWidget(ad: _bannerAd!),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 10,
              child: Consumer<SubscriptionProvider>(
                builder: (context, subscriptionProvider, _) {
                  if (subscriptionProvider.isPremium) {
                    return const SizedBox.shrink();
                  }
                  return Material(
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
