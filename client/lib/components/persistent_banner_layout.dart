import 'package:flutter/material.dart';
import 'banner_ad.dart';

class PersistentBannerLayout extends StatelessWidget {
  final Widget child;

  const PersistentBannerLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        child,
        // Banner ad at the bottom
        const BannerAdWidget(),
      ],
    );
  }
}
