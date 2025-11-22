import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import '../services/tutorial_service.dart';

/// Global keys for tutorial showcase targets
class TutorialKeys {
  static final GlobalKey homeHero = GlobalKey();
  static final GlobalKey homeYourRecipes = GlobalKey();
  static final GlobalKey homeDiscover = GlobalKey();
  static final GlobalKey homeCollections = GlobalKey();
  static final GlobalKey homeFeatures = GlobalKey();
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
            ),
          );
        }
      },
      enableAutoScroll: true,
      scrollDuration: const Duration(milliseconds: 500),
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
void startTutorial(BuildContext context, List<GlobalKey> keys) {
  debugPrint('🚀 Starting tutorial with ${keys.length} keys');
  if (keys.isNotEmpty) {
    try {
      ShowcaseView.get().startShowCase(keys);
    } catch (e) {
      debugPrint('❌ Error starting showcase: $e');
    }
  }
}

/// Tutorial showcase wrapper widget
class TutorialShowcase extends StatelessWidget {
  final GlobalKey showcaseKey;
  final String title;
  final String description;
  final Widget child;
  final EdgeInsets? targetPadding;

  const TutorialShowcase({
    super.key,
    required this.showcaseKey,
    required this.title,
    required this.description,
    required this.child,
    this.targetPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Showcase(
      key: showcaseKey,
      title: title,
      description: description,
      targetPadding: targetPadding ?? const EdgeInsets.all(4),
      child: child,
    );
  }
}
