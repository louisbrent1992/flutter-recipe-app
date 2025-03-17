import 'package:flutter/material.dart';
import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:recipease/screens/discover_recipes.dart';
import 'package:recipease/screens/favorite_recipes.dart';
import 'package:recipease/screens/generate_recipe_screen.dart';
import 'package:recipease/screens/home_screen.dart';
import 'package:recipease/screens/import_details_screen.dart';
import 'package:recipease/screens/import_list.dart';
import 'package:recipease/screens/import_recipe_screen.dart';
import 'package:recipease/screens/recipe_detail_screen.dart';
import 'package:recipease/screens/settings_screen.dart';
import 'package:recipease/theme/theme.dart';
import 'components/bottom_nav_bar.dart'; // Import the BottomNavBar

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late StreamSubscription _intentSub;
  final _sharedFiles = <SharedMediaFile>[];

  @override
  void initState() {
    super.initState();

    // Listen to media sharing coming from outside the app while the app is in the memory.
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (value) {
        if (!mounted) return;
        setState(() {
          _sharedFiles.clear();
          _sharedFiles.addAll(value);

          print(value);
        });

        // navigate to share_intent screen with data
        if (_sharedFiles.isNotEmpty) {
          navigatorKey.currentState?.pushNamed(
            '/importDetails',
            arguments: _sharedFiles,
          );
        }
      },
      onError: (err) {
        print("getIntentDataStream error: $err");
      },
    );

    // Get the media sharing coming from outside the app while the app is closed.
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (!mounted) return;
      setState(() {
        _sharedFiles.clear();
        _sharedFiles.addAll(value);
        print(value);
      });

      // navigate to share_intent screen with data
      if (_sharedFiles.isNotEmpty) {
        navigatorKey.currentState?.pushNamed(
          '/importDetails',
          arguments: _sharedFiles,
        );
      }
      // Tell the library that we are done processing the intent.
      ReceiveSharingIntent.instance.reset();
    });
  }

  @override
  void dispose() {
    _intentSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Recipe App',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: appThemeData.colorScheme,
        ),
        debugShowCheckedModeBanner: false,

        home: const BottomNavBar(), // Use BottomNavBar as the home widget
        routes: {
          '/home': (context) => const HomeScreen(),
          '/generate': (context) => const GenerateRecipeScreen(),
          '/importDetails': (context) => const ImportDetailsScreen(),
          '/import': (context) => const ImportRecipeScreen(),
          '/importList': (context) => const ImportListScreen(),
          '/favorite': (context) => const FavoriteRecipesScreen(),
          '/settings': (context) => const SettingsScreen(),

          // '/notifications': (context) => const NotificationsScreen(),
          '/recipe': (context) => const RecipeDetailScreen(recipe: null),
          '/discover': (context) => const DiscoverRecipesScreen(),
        },
      ),
    );
  }
}
