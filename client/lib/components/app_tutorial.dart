import 'dart:async';
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import '../services/tutorial_service.dart';

/// Global keys for tutorial showcase targets
class TutorialKeys {
  static final GlobalKey homeHero = GlobalKey();
  static final GlobalKey homeYourRecipes = GlobalKey();
  static final GlobalKey homeCommunity = GlobalKey();
  static final GlobalKey homeDiscover = GlobalKey();
  static final GlobalKey homeCollections = GlobalKey();
  static final GlobalKey homeFeatures = GlobalKey();
  static final GlobalKey navDrawerMenu = GlobalKey();
  static final GlobalKey creditBalance = GlobalKey();
  static final GlobalKey bottomNavHome = GlobalKey();
  static final GlobalKey bottomNavDiscover = GlobalKey();
  static final GlobalKey bottomNavMyRecipes = GlobalKey();
  static final GlobalKey bottomNavGenerate = GlobalKey();
  static final GlobalKey bottomNavSettings = GlobalKey();
}

/// Tutorial overlay component that guides users through the app
class AppTutorial extends StatefulWidget {
  final Widget child;
  final bool autoStart;

  const AppTutorial({super.key, required this.child, this.autoStart = false});

  @override
  State<AppTutorial> createState() => _AppTutorialState();
}

class _AppTutorialState extends State<AppTutorial> {
  final TutorialService _tutorialService = TutorialService();
  late final ShowcaseView _showcaseView;

  @override
  void initState() {
    super.initState();
    _showcaseView = ShowcaseView.register(
      onStart: (index, key) {
        _tutorialService.notifyStepChanged(key);
      },
      onFinish: () async {
        await _tutorialService.completeTutorial();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Tutorial completed! 🎉'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 6,
            ),
          );
          // Notify that tutorial is complete (triggers ad loading)
          _tutorialService.notifyStepChanged(GlobalKey());
        }
      },
      enableAutoScroll: true,
      scrollDuration: const Duration(milliseconds: 500), // Slower, smoother scroll
      blurValue: 0, // Disable blur for better performance
    );
  }

  @override
  void dispose() {
    _showcaseView.unregister();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Helper method to start the tutorial showcase
/// Uses a microtask to ensure it runs after the current build cycle completes
void startTutorial(BuildContext context, List<GlobalKey> keys) {
  if (keys.isEmpty) return;
  
  // Clear manual restart flag since tutorial is starting
  TutorialService().clearManualRestartFlag();
  
  // Use scheduleMicrotask to ensure this runs after current frame completes
  // This prevents stuttering by ensuring all widgets are fully built
  scheduleMicrotask(() {
    try {
  ShowcaseView.get().startShowCase(keys);
    } catch (e) {
      debugPrint('❌ Error starting showcase: $e');
    }
  });
}

/// Tutorial showcase wrapper widget with advanced styling
class TutorialShowcase extends StatelessWidget {
  final GlobalKey showcaseKey;
  final String title;
  final String description;
  final Widget child;
  final EdgeInsets? targetPadding;
  final ShapeBorder? targetShapeBorder;
  final bool isCircular;

  const TutorialShowcase({
    super.key,
    required this.showcaseKey,
    required this.title,
    required this.description,
    required this.child,
    this.targetPadding,
    this.targetShapeBorder,
    this.isCircular = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Determine shape border
    final ShapeBorder shapeBorder = targetShapeBorder ?? 
        (isCircular 
            ? const CircleBorder() 
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ));

    return Showcase(
      key: showcaseKey,
      title: title,
      description: description,
      targetPadding: targetPadding ?? const EdgeInsets.all(8),
      targetShapeBorder: shapeBorder,
      // Advanced tooltip styling
      tooltipBackgroundColor: colorScheme.surface,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
        letterSpacing: 0.5,
      ),
      descTextStyle: TextStyle(
        fontSize: 15,
        color: colorScheme.onSurface.withValues(alpha: 0.8),
        height: 1.4,
      ),
      tooltipPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),
      tooltipBorderRadius: BorderRadius.circular(16),
      // Animation settings - stable to prevent stuttering
      movingAnimationDuration: const Duration(milliseconds: 300),
      disableMovingAnimation: true, // Disable moving animation to prevent vertical jitter
      scaleAnimationDuration: const Duration(milliseconds: 300),
      scaleAnimationCurve: Curves.easeOutQuart,
      disableScaleAnimation: true, // Keep target size stable
      child: child,
    );
  }
}
