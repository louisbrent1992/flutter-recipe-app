import 'package:flutter/material.dart';
import 'banner_ad.dart';
import 'floating_bottom_bar.dart';

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
        // Banner ad at the bottom (hide on Recipe Details since it uses inline ads)
        if (routeName != '/recipeDetail') const BannerAdWidget(),
        // Global floating bottom navigation (avoid duplicating on Home which already includes it)
        if (routeName != '/discover' && routeName != '/myRecipes')
          const FloatingBottomBar(),
      ],
    );
  }
}
