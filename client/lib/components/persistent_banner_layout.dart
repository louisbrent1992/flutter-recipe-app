import 'package:flutter/material.dart';
import 'banner_ad.dart';
import 'floating_bottom_bar.dart';
import 'offline_banner.dart';

class PersistentBannerLayout extends StatelessWidget {
  final Widget child;

  const PersistentBannerLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final routeName = ModalRoute.of(context)?.settings.name ?? '';
    return Stack(
      children: [
        // Main content
        child,
        // Offline banner at the top
        const Positioned(top: 0, left: 0, right: 0, child: OfflineBanner()),
        // Banner ad at the bottom (hide on screens that use inline ads)
        if (routeName != '/recipeDetail' &&
            routeName != '/discover' &&
            routeName != '/myRecipes' &&
            routeName != '/community' &&
            routeName != '/generate' &&
            routeName != '/import' &&
            routeName != '/home' &&
            routeName != '/settings' &&
            routeName != '/collections' &&
            routeName != '/subscription')
          const BannerAdWidget(),
        // Global floating bottom navigation (avoid duplicating on Home which already includes it)
        if (routeName != '/discover' && routeName != '/myRecipes' && routeName != '/community')
          const FloatingBottomBar(),
      ],
    );
  }
}
