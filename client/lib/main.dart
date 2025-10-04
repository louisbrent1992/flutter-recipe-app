import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipease/components/persistent_banner_layout.dart';
import 'package:recipease/firebase_options.dart';
import 'package:recipease/screens/my_recipes_screen.dart';
import 'package:recipease/screens/discover_recipes.dart';
import 'package:recipease/screens/generate_recipe_screen.dart';
import 'package:recipease/screens/home_screen.dart';
import 'package:recipease/screens/recipe_edit_screen.dart';
import 'package:recipease/screens/import_recipe_screen.dart';
import 'package:recipease/screens/recipe_detail_screen.dart';
import 'package:recipease/screens/settings_screen.dart';
import 'package:recipease/screens/auth/login_screen.dart';
import 'package:recipease/screens/auth/register_screen.dart';
import 'package:recipease/screens/recipe_collections_screen.dart';
import 'package:recipease/screens/collection_detail_screen.dart';
import 'package:recipease/screens/subscription_screen.dart';
import 'package:recipease/screens/add_recipes_to_collection_screen.dart';
import 'package:recipease/screens/splash_screen.dart';
import 'package:recipease/config/app_config.dart';
import 'package:recipease/theme/theme.dart';
import 'package:recipease/providers/auth_provider.dart';
import 'package:recipease/providers/user_profile_provider.dart';
import 'package:recipease/providers/theme_provider.dart';
import 'package:recipease/providers/notification_provider.dart';
import 'package:recipease/providers/recipe_provider.dart';
import 'package:recipease/providers/subscription_provider.dart';
import 'package:recipease/models/recipe.dart';
import 'package:recipease/models/recipe_collection.dart';
import 'package:recipease/services/collection_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_handler/share_handler.dart';
import 'package:recipease/services/permission_service.dart';
// import 'package:receive_sharing_intent/receive_sharing_intent.dart'; // REPLACED WITH share_handler
import 'dart:async';
import 'screens/generated_recipes_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final kWebRecaptchaSiteKey = '6Lemcn0dAAAAABLkf6aiiHvpGD6x-zF3nOSDU2M8';

// Debug flag to disable ads for screenshots - set to true to hide ads
const bool hideAds = true;

// Alternative: Environment-based approach
// const bool HIDE_ADS_FOR_SCREENSHOTS = bool.fromEnvironment('HIDE_ADS', defaultValue: false);
// Then run with: flutter run --dart-define=HIDE_ADS=true

/// Initializes the app.
///
/// Ensures Flutter is bound to the widgets layer, initializes Firebase, and
/// loads the app's preferences from local storage. Then, runs the app with
/// the loaded preferences.
///
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize MobileAds with test device configuration
  await MobileAds.instance.initialize();

  // Configure test devices
  MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(
      testDeviceIds: ['02A173696D1667C3CA2143D2D279EE38'],
      tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
      tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.unspecified,
    ),
  );

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Firebase App Check with proper configuration
  if (kDebugMode) {
    // Use debug provider for development
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
    print('Firebase App Check initialized in debug mode');
  } else {
    // Use device check provider for production
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.deviceCheck,
    );
    print('Firebase App Check initialized in production mode');
  }

  await Hive.initFlutter();
  await Hive.openBox('preferences');

  runApp(MyApp(Key('key')));
}

/// Platform-aware scroll behavior:
/// - iOS/macOS: Bouncing
/// - Android/Windows/Linux/Web: Clamping (no over-stretch)
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Disable glow/stretch indicators to avoid over-drag visuals on Android
    return child;
  }
}

class MyApp extends StatefulWidget {
  const MyApp(Key? key) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<SharedMedia>? _mediaStreamSub;
  StreamSubscription<Uri>? _linkStreamSub;
  final PermissionService _permissionService = PermissionService();
  String? _lastHandledShareUrl;
  DateTime? _lastHandledAt;

  @override
  void initState() {
    super.initState();
    _initReceiveSharing();
    _initDeepLinkHandling();

    // Request necessary permissions when app starts
    _requestInitialPermissions();
  }

  // Request initial permissions needed for the app
  Future<void> _requestInitialPermissions() async {
    // Request notification permission
    await _permissionService.requestNotificationPermission();

    // We don't request camera and photos permissions on startup
    // as it's better to request them when they're needed
  }

  // Initialize deep link handling for ShareMedia URL scheme
  void _initDeepLinkHandling() {
    try {
      // Simple URL scheme handling using platform channels
      // This will be called when the app receives a URL scheme
      _handleInitialUrlScheme();
    } catch (e) {
      debugPrint('Error initializing deep link handling: $e');
    }
  }

  // Handle initial URL scheme (for cold starts from share extension)
  void _handleInitialUrlScheme() {
    // This method will be enhanced with platform-specific URL handling
    // For now, we rely on the existing receive_sharing_intent mechanism
    debugPrint('URL scheme handling initialized');
  }

  // Initialize share_handler to receive shared content
  Future<void> _initReceiveSharing() async {
    final handler = ShareHandlerPlatform.instance;

    // Get initial shared media when app launched from share
    final SharedMedia? initialMedia = await handler.getInitialSharedMedia();
    if (initialMedia != null) {
      final maybeUrl = _extractUrlFromSharedMedia(initialMedia);
      if (maybeUrl != null) {
        // Wait for the app to be fully initialized before handling shared content
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _handleSharedUrlWithDelay(maybeUrl),
        );
      }
    }

    // Listen for media while app is in memory
    _mediaStreamSub = handler.sharedMediaStream.listen((SharedMedia media) {
      final maybeUrl = _extractUrlFromSharedMedia(media);
      if (maybeUrl != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _handleSharedUrl(maybeUrl),
        );
      }
    });
  }

  // Handle shared URL with additional delay for cold start
  void _handleSharedUrlWithDelay(String url) {
    // Add a small delay to ensure the app is fully initialized
    Future.delayed(
      Duration(milliseconds: AppConfig.importNavigationDelayMs),
      () {
        _handleSharedUrl(url);
      },
    );
  }

  // Extract a usable URL from SharedMedia
  String? _extractUrlFromSharedMedia(SharedMedia media) {
    // Check content (text) first
    if (media.content != null && media.content!.isNotEmpty) {
      if (_looksLikeUrl(media.content!)) return media.content!;
    }

    // Check attachments
    if (media.attachments != null) {
      for (final attachment in media.attachments!) {
        if (attachment != null && _looksLikeUrl(attachment.path)) {
          return attachment.path;
        }
      }
    }

    return null;
  }

  bool _looksLikeUrl(String value) {
    final v = value.toLowerCase();
    return v.startsWith('http://') ||
        v.startsWith('https://') ||
        v.startsWith('www.');
  }

  // Import recipe directly from shared media
  void _importRecipeFromSharedMedia(String url) {
    // Do not import in the background here.
    // Only navigate to the import screen, which shows the "Importing" dialog
    // and handles the import UX consistently.
    _navigateToImportScreen(url);
  }

  // Handle shared URL once, de-duping initial and stream deliveries
  void _handleSharedUrl(String url) {
    final now = DateTime.now();
    // De-dupe: if the same URL was handled within the last 2 seconds, skip
    if (_lastHandledShareUrl == url && _lastHandledAt != null) {
      final diff = now.difference(_lastHandledAt!);
      if (diff.inSeconds < 30) {
        return;
      }
    }
    _lastHandledShareUrl = url;
    _lastHandledAt = now;
    _importRecipeFromSharedMedia(url);
  }

  // Navigate to the import screen with the shared URL (kept for manual import)
  void _navigateToImportScreen(String url) {
    // Wait for the navigator to be ready before attempting navigation
    _waitForNavigatorAndNavigate(url);
  }

  // Wait for navigator to be ready and then navigate
  void _waitForNavigatorAndNavigate(String url) {
    // Check if navigator is ready
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.pushNamed('/import', arguments: url);
      return;
    }

    // If not ready, wait for the next frame and try again
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamed('/import', arguments: url);
      } else {
        // If still not ready after a frame, wait a bit longer
        Future.delayed(const Duration(milliseconds: 500), () {
          if (navigatorKey.currentState != null) {
            navigatorKey.currentState!.pushNamed('/import', arguments: url);
          } else {
            debugPrint(
              'Failed to navigate to import screen - navigator not ready',
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    try {
      _mediaStreamSub?.cancel();
      _linkStreamSub?.cancel();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => UserProfileProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(Hive.box('preferences')),
        ),
        ChangeNotifierProvider(create: (_) => RecipeProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => CollectionService()),
      ],
      child: Consumer2<AuthService, ThemeProvider>(
        builder: (context, authService, themeProvider, _) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Recipease',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode:
                themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            debugShowCheckedModeBanner: false, // Cleaner debug experience
            showSemanticsDebugger: false, // Disable semantics debugger
            showPerformanceOverlay:
                false, // Disable performance overlay by default
            checkerboardRasterCacheImages:
                false, // Disable raster cache checkerboard
            checkerboardOffscreenLayers:
                false, // Disable offscreen layers checkerboard
            // Enhanced user experience configurations
            supportedLocales: const [
              Locale('en', 'US'),
              Locale('en', 'GB'),
              Locale('es', 'ES'),
              Locale('fr', 'FR'),
            ],
            // Localization delegates for future internationalization
            localizationsDelegates: const [
              // Add when implementing internationalization
              // GlobalMaterialLocalizations.delegate,
              // GlobalWidgetsLocalizations.delegate,
              // GlobalCupertinoLocalizations.delegate,
            ],
            // Performance and accessibility configurations
            scrollBehavior: AppScrollBehavior(),
            // Error handling and debugging
            builder: (context, child) {
              // Add error boundary for better error handling
              ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Theme.of(context).colorScheme.error,
                          size: 60,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Something went wrong!',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        if (kDebugMode)
                          Text(
                            errorDetails.exception.toString(),
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                );
              };
              return child!;
            },
            home: const SplashScreen(),
            routes: {
              '/splash': (context) => const SplashScreen(),
              '/home':
                  (context) =>
                      const PersistentBannerLayout(child: HomeScreen()),
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/discover': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                String? initialQuery;
                String? initialDifficulty;
                String? initialTag;

                if (args is Map) {
                  try {
                    initialQuery = args['query'] as String?;
                    initialDifficulty = args['difficulty'] as String?;
                    initialTag = args['tag'] as String?;
                  } catch (_) {
                    // ignore malformed args
                  }
                }

                return PersistentBannerLayout(
                  child: DiscoverRecipesScreen(
                    initialQuery: initialQuery,
                    initialDifficulty: initialDifficulty,
                    initialTag: initialTag,
                  ),
                );
              },
              '/generate':
                  (context) => const PersistentBannerLayout(
                    child: GenerateRecipeScreen(),
                  ),
              '/import':
                  (context) => PersistentBannerLayout(
                    child: ImportRecipeScreen(
                      sharedUrl:
                          ModalRoute.of(context)?.settings.arguments as String?,
                    ),
                  ),
              '/recipeEdit':
                  (context) => PersistentBannerLayout(
                    child: RecipeEditScreen(
                      recipe:
                          ModalRoute.of(context)?.settings.arguments as Recipe?,
                    ),
                  ),
              '/myRecipes':
                  (context) =>
                      const PersistentBannerLayout(child: MyRecipesScreen()),
              '/recipeDetail':
                  (context) => PersistentBannerLayout(
                    child: RecipeDetailScreen(
                      recipe:
                          ModalRoute.of(context)!.settings.arguments as Recipe,
                    ),
                  ),
              '/settings':
                  (context) =>
                      const PersistentBannerLayout(child: SettingsScreen()),
              '/collections':
                  (context) => const PersistentBannerLayout(
                    child: RecipeCollectionScreen(),
                  ),
              '/collectionDetail':
                  (context) => PersistentBannerLayout(
                    child: CollectionDetailScreen(
                      collection:
                          ModalRoute.of(context)!.settings.arguments
                              as RecipeCollection,
                    ),
                  ),
              '/addRecipesToCollection':
                  (context) => PersistentBannerLayout(
                    child: AddRecipesToCollectionScreen(
                      collection:
                          ModalRoute.of(context)!.settings.arguments
                              as RecipeCollection,
                    ),
                  ),
              '/generatedRecipes':
                  (context) => const PersistentBannerLayout(
                    child: GeneratedRecipesScreen(),
                  ),
              '/subscription':
                  (context) =>
                      const PersistentBannerLayout(child: SubscriptionScreen()),
            },
          );
        },
      ),
    );
  }
}
