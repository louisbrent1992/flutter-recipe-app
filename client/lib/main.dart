import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;
import 'package:provider/provider.dart';
import 'package:recipease/components/persistent_banner_layout.dart';
import 'package:recipease/firebase_options.dart';
import 'package:recipease/screens/my_recipes_screen.dart';
import 'package:recipease/screens/discover_recipes.dart';
// import 'package:recipease/screens/community_screen.dart';
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
import 'package:recipease/screens/random_recipe_screen.dart';
import 'package:recipease/screens/splash_screen.dart';
import 'package:recipease/theme/theme.dart';
import 'package:recipease/providers/auth_provider.dart';
import 'package:recipease/providers/user_profile_provider.dart';
import 'package:recipease/providers/theme_provider.dart';
import 'package:recipease/providers/notification_provider.dart';
import 'package:recipease/providers/recipe_provider.dart';
import 'package:recipease/providers/subscription_provider.dart';
import 'package:recipease/providers/dynamic_ui_provider.dart';
import 'package:recipease/components/dynamic_background.dart';
import 'package:recipease/models/recipe.dart';
import 'package:recipease/models/recipe_collection.dart';
import 'package:recipease/services/collection_service.dart';
import 'package:recipease/services/recipe_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_handler/share_handler.dart';
import 'package:recipease/services/permission_service.dart';
import 'dart:async';
import 'screens/generated_recipes_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:convert';
import 'package:recipease/services/notification_scheduler.dart';
import 'package:recipease/services/game_center_service.dart';
import 'package:recipease/services/debug_settings.dart';
import 'package:recipease/services/tutorial_service.dart';
import 'package:recipease/components/app_tutorial.dart';
import 'package:recipease/providers/connectivity_provider.dart';
import 'package:recipease/services/local_storage_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final kWebRecaptchaSiteKey = '6Lemcn0dAAAAABLkf6aiiHvpGD6x-zF3nOSDU2M8';

// Debug flag to disable ads for screenshots - set to false to show ads in testing
const bool hideAds = false;

// Push notifications: background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

/// Initializes the app.
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

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize timezone database
  tz.initializeTimeZones();
  try {
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    final String timezoneName = tzInfo.identifier;
    tz.setLocalLocation(tz.getLocation(timezoneName));
  } catch (_) {}

  // Set background handler early
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize Firebase App Check
  if (kDebugMode) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
    print('Firebase App Check initialized in debug mode');
  } else {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.deviceCheck,
    );
    print('Firebase App Check initialized in production mode');
  }

  await Hive.initFlutter();
  await Hive.openBox('preferences');

  // Initialize Services
  try {
    final localStorageService = LocalStorageService();
    await localStorageService.initialize();
  } catch (e) {
    debugPrint('LocalStorageService initialization failed: $e');
  }

  await DebugSettings().init();
  await TutorialService().init();

  try {
    final gameCenterService = GameCenterService();
    await gameCenterService.initialize();
  } catch (e) {
    debugPrint('Game Center initialization skipped: $e');
  }

  runApp(MyApp(Key('key')));
}

/// Platform-aware scroll behavior
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
    return child;
  }
}

class MyApp extends StatefulWidget {
  const MyApp(Key? key) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();

  static RouteObserver<PageRoute> get routeObserver =>
      _MyAppState.routeObserver;
}

// Global function to access pending shared URL from anywhere
String? getPendingSharedUrl() => _MyAppState._getPendingSharedUrl();

// Global function to access pending notification payload from anywhere
String? getPendingNotificationPayload() =>
    _MyAppState._getPendingNotificationPayload();

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  StreamSubscription<SharedMedia>? _mediaStreamSub;
  StreamSubscription<Uri>? _linkStreamSub;
  final PermissionService _permissionService = PermissionService();
  String? _lastHandledShareUrl;
  DateTime? _lastHandledAt;
  static String? _pendingSharedUrl;
  static String? _processedInitialUrl;
  static String? _pendingNotificationPayload;
  NotificationResponse? _lastNotificationResponse;

  static final RouteObserver<PageRoute> routeObserver =
      RouteObserver<PageRoute>();
  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'recipease_general',
        'General',
        description: 'General notifications',
        importance: Importance.high,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initReceiveSharing();
    _initDeepLinkHandling();
    _initPushNotifications();
    _requestInitialPermissions();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _checkForPendingNotificationResponse();
      });
    }
  }

  Future<void> _checkForPendingNotificationResponse() async {
    try {
      final details =
          await _localNotifications.getNotificationAppLaunchDetails();

      if (details != null &&
          details.didNotificationLaunchApp &&
          details.notificationResponse != null) {
        final response = details.notificationResponse!;
        final payload = response.payload;

        if (_lastNotificationResponse?.payload != payload &&
            payload != null &&
            payload.isNotEmpty) {
          _handleNotificationNavigation(payload);
          _lastNotificationResponse = response;
        }
      }
    } catch (e) {
      debugPrint('Error checking for pending notification: $e');
    }
  }

  Future<void> _requestInitialPermissions() async {
    await _permissionService.requestNotificationPermission();
    await _permissionService.requestScheduleExactAlarmPermission();
  }

  void _initDeepLinkHandling() {
    try {
      _handleInitialUrlScheme();
    } catch (e) {
      debugPrint('Error initializing deep link handling: $e');
    }
  }

  Future<void> _initPushNotifications() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.setAutoInitEnabled(true);
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await messaging.getToken();
      if (kDebugMode) {
        debugPrint('FCM token: ${token ?? 'null'}');
      }

      const androidInit = AndroidInitializationSettings(
        '@mipmap/launcher_icon',
      );
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      await _localNotifications.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
        onDidReceiveNotificationResponse: (resp) {
          _lastNotificationResponse = resp;
          final payload = resp.payload;
          if (payload != null && payload.isNotEmpty) {
            _handleNotificationNavigation(payload);
          }
        },
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_androidChannel);

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      NotificationScheduler.init(_localNotifications);

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen((message) {
        final notif = message.notification;
        if (notif != null) {
          final Map<String, dynamic> args = {};
          if (message.data['recipeId'] != null) {
            args['recipeId'] = message.data['recipeId'];
          }
          if (message.data['query'] != null || message.data['tag'] != null) {
            args['query'] =
                (message.data['query'] as String?) ??
                (message.data['tag'] as String?) ??
                '';
          }

          final payload = jsonEncode({
            'route': (message.data['route'] as String?) ?? '/home',
            'args': args,
          });

          _localNotifications.show(
            notif.hashCode,
            notif.title,
            notif.body,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'recipease_general',
                'General',
                importance: Importance.high,
                priority: Priority.high,
              ),
              iOS: DarwinNotificationDetails(),
            ),
            payload: payload,
          );
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        final payload = jsonEncode({
          'route': message.data['route'] ?? '/home',
          'args': message.data['args'] ?? {},
        });
        _handleNotificationNavigation(payload);
      });

      final initialMsg = await messaging.getInitialMessage();
      if (initialMsg != null) {
        final payload = jsonEncode({
          'route': initialMsg.data['route'] ?? '/home',
          'args': initialMsg.data['args'] ?? {},
        });
        _pendingNotificationPayload = payload;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final notif = Provider.of<NotificationProvider>(
            context,
            listen: false,
          );
          await NotificationScheduler.scheduleAll(
            dailyInspiration: notif.catDailyInspiration,
            mealPrep: notif.catMealPrep,
            seasonal: notif.catSeasonal,
            quickMeals: notif.catQuickMeals,
            budget: notif.catBudget,
            keto: notif.catKeto,
          );
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('Push notification init error: $e');
    }
  }

  void _handleNotificationNavigation(String payload) {
    try {
      final obj = jsonDecode(payload) as Map<String, dynamic>;
      final route = obj['route'] as String?;
      final args = obj['args'] as Map<String, dynamic>?;

      if (route == null || route.isEmpty) {
        return;
      }

      _waitForNavigatorAndNavigateToRoute(route, args);
    } catch (e) {
      _waitForNavigatorAndNavigateToRoute(payload, null);
    }
  }

  void _waitForNavigatorAndNavigateToRoute(
    String route,
    Map<String, dynamic>? args,
  ) {
    if (navigatorKey.currentState != null) {
      _performNavigation(route, args);
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentState != null) {
        _performNavigation(route, args);
      } else {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (navigatorKey.currentState != null) {
            _performNavigation(route, args);
          }
        });
      }
    });
  }

  void _performNavigation(String route, Map<String, dynamic>? args) async {
    try {
      final navigatorState = navigatorKey.currentState;
      if (navigatorState == null) {
        return;
      }

      if (route == '/recipeDetail' &&
          args != null &&
          args['recipeId'] != null) {
        final recipeId = args['recipeId'] as String;
        try {
          final response = await RecipeService.getRecipeById(recipeId);
          if (response.success && response.data != null) {
            navigatorState.pushNamed('/recipeDetail', arguments: response.data);
          } else {
            debugPrint(
              'Failed to fetch recipe for notification: ${response.message}',
            );
            navigatorState.pushNamed('/home');
          }
        } catch (e) {
          debugPrint('Error fetching recipe for notification: $e');
          navigatorState.pushNamed('/home');
        }
        return;
      }

      Map<String, String>? stringArgs;
      if (args != null && args.isNotEmpty) {
        stringArgs = args.map(
          (key, value) => MapEntry(key, value?.toString() ?? ''),
        );
      }

      navigatorState.pushNamed(route, arguments: stringArgs ?? args);
    } catch (e) {
      debugPrint('Navigation error to $route: $e');
    }
  }

  void _handleInitialUrlScheme() {}

  Future<void> _initReceiveSharing() async {
    final handler = ShareHandlerPlatform.instance;
    final SharedMedia? initialMedia = await handler.getInitialSharedMedia();
    if (initialMedia != null) {
      final maybeUrl = _extractUrlFromSharedMedia(initialMedia);
      if (maybeUrl != null) {
        _pendingSharedUrl = maybeUrl;
        _processedInitialUrl = maybeUrl;
      }
    }

    _mediaStreamSub = handler.sharedMediaStream.listen((SharedMedia media) {
      final maybeUrl = _extractUrlFromSharedMedia(media);
      if (maybeUrl != null) {
        if (_processedInitialUrl == maybeUrl) {
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _handleSharedUrl(maybeUrl),
        );
      }
    });
  }

  String? _extractUrlFromSharedMedia(SharedMedia media) {
    if (media.content != null && media.content!.isNotEmpty) {
      if (_looksLikeUrl(media.content!)) return media.content!;
    }
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

  void _importRecipeFromSharedMedia(String url) {
    _navigateToImportScreen(url);
  }

  void _handleSharedUrl(String url) {
    final now = DateTime.now();
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

  void _navigateToImportScreen(String url) {
    _waitForNavigatorAndNavigate(url);
  }

  void _waitForNavigatorAndNavigate(String url) {
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.pushNamed('/import', arguments: url);
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamed('/import', arguments: url);
      } else {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (navigatorKey.currentState != null) {
            navigatorKey.currentState!.pushNamed('/import', arguments: url);
          }
        });
      }
    });
  }

  static String? _getPendingSharedUrl() {
    final url = _pendingSharedUrl;
    _pendingSharedUrl = null;
    return url;
  }

  static String? _getPendingNotificationPayload() {
    final payload = _pendingNotificationPayload;
    _pendingNotificationPayload = null;
    return payload;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    try {
      _mediaStreamSub?.cancel();
      _linkStreamSub?.cancel();
    } catch (_) {}
    super.dispose();
  }

  static final Map<String, Widget Function(dynamic)> _routes = {
    '/splash': (args) => const SplashScreen(),
    '/home': (args) => const PersistentBannerLayout(child: HomeScreen()),
    '/login': (args) => const LoginScreen(),
    '/register': (args) => const RegisterScreen(),
    '/discover': (args) {
      String? initialQuery;
      String? initialDifficulty;
      String? initialTag;
      String? displayQuery;

      if (args is Map) {
        try {
          initialQuery = (args['query'] as String?) ?? (args['tag'] as String?);
          initialDifficulty = args['difficulty'] as String?;
          displayQuery = args['displayQuery'] as String?;
          initialTag = null;
        } catch (_) {}
      }

      return PersistentBannerLayout(
        child: DiscoverRecipesScreen(
          initialQuery: initialQuery,
          initialDifficulty: initialDifficulty,
          initialTag: initialTag,
          displayQuery: displayQuery,
        ),
      );
    },
    '/generate':
        (args) => const PersistentBannerLayout(child: GenerateRecipeScreen()),
    '/import':
        (args) => PersistentBannerLayout(
          child: ImportRecipeScreen(sharedUrl: args as String?),
        ),
    '/recipeEdit':
        (args) => PersistentBannerLayout(
          child: RecipeEditScreen(recipe: args as Recipe?),
        ),
    '/myRecipes':
        (args) => const PersistentBannerLayout(child: MyRecipesScreen()),
    '/recipeDetail':
        (args) => PersistentBannerLayout(
          child: RecipeDetailScreen(recipe: args as Recipe),
        ),
    '/settings':
        (args) => const PersistentBannerLayout(child: SettingsScreen()),
    '/collections':
        (args) => const PersistentBannerLayout(child: RecipeCollectionScreen()),
    '/collectionDetail':
        (args) => PersistentBannerLayout(
          child: CollectionDetailScreen(collection: args as RecipeCollection),
        ),
    '/addRecipesToCollection':
        (args) => PersistentBannerLayout(
          child: AddRecipesToCollectionScreen(
            collection: args as RecipeCollection,
          ),
        ),
    '/generatedRecipes':
        (args) => const PersistentBannerLayout(child: GeneratedRecipesScreen()),
    '/randomRecipe':
        (args) => const PersistentBannerLayout(child: RandomRecipeScreen()),
    '/subscription':
        (args) => const PersistentBannerLayout(child: SubscriptionScreen()),
  };

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
        ChangeNotifierProvider(create: (_) => DynamicUiProvider()),
        ChangeNotifierProvider(create: (_) => CollectionService()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
      ],
      child: Consumer2<AuthService, ThemeProvider>(
        builder: (context, authService, themeProvider, _) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            navigatorObservers: [MyApp.routeObserver],
            title: 'Recipease',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode:
                themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            debugShowCheckedModeBanner: false,
            showSemanticsDebugger: false,
            showPerformanceOverlay: false,
            checkerboardRasterCacheImages: false,
            checkerboardOffscreenLayers: false,
            supportedLocales: const [
              Locale('en', 'US'),
              Locale('en', 'GB'),
              Locale('es', 'ES'),
              Locale('fr', 'FR'),
            ],
            localizationsDelegates: const [],
            scrollBehavior: AppScrollBehavior(),
            onGenerateRoute: (settings) {
              final routeBuilder = _MyAppState._routes[settings.name];
              if (routeBuilder == null) return null;

              final widget = routeBuilder(settings.arguments);

              if (Platform.isIOS) {
                return CupertinoPageRoute(
                  settings: settings,
                  builder: (context) {
                    // FIX: Wrap the route content in the DynamicGlobalBackground.
                    // This creates an "opaque" layer for the transition animation (fixing the trail bug)
                    // while showing the correct background instead of a solid color.
                    return Stack(
                      children: [
                        const Positioned.fill(
                          child: RepaintBoundary(
                            child: DynamicGlobalBackground(),
                          ),
                        ),
                        widget,
                      ],
                    );
                  },
                );
              } else {
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => widget,
                );
              }
            },
            builder: (context, child) {
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

              return AppTutorial(
                child: Consumer<DynamicUiProvider>(
                  builder: (context, dyn, _) {
                    final hasBg = dyn.config?.globalBackground != null;

                    return Stack(
                      children: [
                        // The Persistent Background (stays still during route transitions)
                        // This remains here so non-iOS platforms or initial load shows it correctly
                        if (hasBg)
                          const Positioned.fill(
                            child: RepaintBoundary(
                              child: DynamicGlobalBackground(),
                            ),
                          ),
                        // The App Content
                        Scaffold(
                          backgroundColor: Colors.transparent,
                          body: child ?? const SizedBox.shrink(),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
            home: const SplashScreen(),
            routes: const {},
          );
        },
      ),
    );
  }
}
