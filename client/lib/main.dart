import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipease/components/persistent_banner_layout.dart';
import 'package:recipease/firebase_options.dart';
import 'package:recipease/screens/my_recipes_screen.dart';
import 'package:recipease/screens/discover_recipes.dart';
import 'package:recipease/screens/community_screen.dart';
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

// Alternative: Environment-based approach
// const bool HIDE_ADS_FOR_SCREENSHOTS = bool.fromEnvironment('HIDE_ADS', defaultValue: false);
// Then run with: flutter run --dart-define=HIDE_ADS=true

// Push notifications: background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

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

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize timezone database for scheduled notifications (optional)
  tz.initializeTimeZones();
  try {
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    // FlutterTimezone 5.x returns TimezoneInfo with 'identifier' property (IANA timezone)
    final String timezoneName = tzInfo.identifier;
    tz.setLocalLocation(tz.getLocation(timezoneName));
  } catch (_) {
    // Fallback: keep default tz.local
  }

  // Set background handler early
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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

  // Initialize Local Storage Service for offline support
  try {
    final localStorageService = LocalStorageService();
    await localStorageService.initialize();
  } catch (e) {
    debugPrint('LocalStorageService initialization failed: $e');
  }

  // Initialize Debug Settings (only in debug mode)
  await DebugSettings().init();

  // Initialize Tutorial Service
  await TutorialService().init();

  // Initialize Game Center (iOS only, fails silently on other platforms)
  try {
    final gameCenterService = GameCenterService();
    await gameCenterService.initialize();
  } catch (e) {
    debugPrint('Game Center initialization skipped: $e');
  }

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
  static String? _pendingSharedUrl; // Static for cross-widget access
  static String?
  _processedInitialUrl; // Track the initial URL to prevent duplicates
  static String?
  _pendingNotificationPayload; // Track notification from cold start
  NotificationResponse?
  _lastNotificationResponse; // Track last notification response
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

    // Request necessary permissions when app starts
    _requestInitialPermissions();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Check for notification responses when app becomes active/resumed
    // This is especially important for iOS where the callback may not fire
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive) {
      // Add a small delay to ensure notification system has processed the tap
      Future.delayed(const Duration(milliseconds: 300), () {
        _checkForPendingNotificationResponse();
      });
    }
  }

  // Check for pending notification response when app resumes
  // This is a workaround for iOS where foreground notification taps may not trigger the callback
  Future<void> _checkForPendingNotificationResponse() async {
    try {
      final details =
          await _localNotifications.getNotificationAppLaunchDetails();

      if (details != null &&
          details.didNotificationLaunchApp &&
          details.notificationResponse != null) {
        final response = details.notificationResponse!;
        final payload = response.payload;

        // Only handle if we haven't already processed this
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

  // Request initial permissions needed for the app
  Future<void> _requestInitialPermissions() async {
    // Request notification permission
    await _permissionService.requestNotificationPermission();

    // Request exact alarm permission for scheduled notifications (Android 12+)
    await _permissionService.requestScheduleExactAlarmPermission();

    // We don't request camera and photos permissions on startup
    // as it's better to request them when they're needed
  }

  // Initialize deep link handling for ShareMedia URL scheme
  void _initDeepLinkHandling() {
    try {
      // Simple URL scheme handling using platform channels
      // This will be called when the app receives a URL scheme
      // Defer Firebase operations until after initialization is complete
      _handleInitialUrlScheme();
    } catch (e) {
      debugPrint('Error initializing deep link handling: $e');
    }
  }

  Future<void> _initPushNotifications() async {
    try {
      // Ask FCM permissions (iOS) in addition to OS-level permission
      final messaging = FirebaseMessaging.instance;
      await messaging.setAutoInitEnabled(true);
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      // Obtain token (use this to target notifications from server)
      final token = await messaging.getToken();
      if (kDebugMode) {
        debugPrint('FCM token: ${token ?? 'null'}');
      }

      // Local notifications init
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
          // Store the response to prevent duplicate processing
          _lastNotificationResponse = resp;

          final payload = resp.payload;
          if (payload != null && payload.isNotEmpty) {
            _handleNotificationNavigation(payload);
          }
        },
      );

      // Android channel
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_androidChannel);

      // iOS: explicitly request notification permissions for local notifications
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      // Initialize scheduler with plugin
      NotificationScheduler.init(_localNotifications);

      // iOS: show alert in foreground
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Foreground messages → show local notification
      FirebaseMessaging.onMessage.listen((message) {
        final notif = message.notification;
        if (notif != null) {
          // Build args from message data
          final Map<String, dynamic> args = {};

          // Handle recipe milestone notifications
          if (message.data['recipeId'] != null) {
            args['recipeId'] = message.data['recipeId'];
          }
          // Handle query-based notifications (discover, etc.)
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

      // App opened from notification (background)
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        final payload = jsonEncode({
          'route': message.data['route'] ?? '/home',
          'args': message.data['args'] ?? {},
        });
        _handleNotificationNavigation(payload);
      });

      // App launched from terminated via notification
      final initialMsg = await messaging.getInitialMessage();
      if (initialMsg != null) {
        // Store payload for splash screen to handle
        // This prevents race condition where splash screen navigates to /home
        // after notification navigation has already pushed a route
        final payload = jsonEncode({
          'route': initialMsg.data['route'] ?? '/home',
          'args': initialMsg.data['args'] ?? {},
        });
        _pendingNotificationPayload = payload;
      }

      // After init, (re)schedule local notifications based on user prefs
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

  // Handle notification navigation with proper error handling
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
      // Backward-compat: treat payload as a simple route string
      _waitForNavigatorAndNavigateToRoute(payload, null);
    }
  }

  // Wait for navigator to be ready and then navigate
  void _waitForNavigatorAndNavigateToRoute(
    String route,
    Map<String, dynamic>? args,
  ) {
    // Check if navigator is ready
    if (navigatorKey.currentState != null) {
      _performNavigation(route, args);
      return;
    }

    // If not ready, wait for the next frame and try again
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentState != null) {
        _performNavigation(route, args);
      } else {
        // If still not ready after a frame, wait a bit longer
        Future.delayed(const Duration(milliseconds: 500), () {
          if (navigatorKey.currentState != null) {
            _performNavigation(route, args);
          }
        });
      }
    });
  }

  // Perform the actual navigation
  void _performNavigation(String route, Map<String, dynamic>? args) async {
    try {
      final navigatorState = navigatorKey.currentState;
      if (navigatorState == null) {
        return;
      }

      // Handle recipe detail navigation - need to fetch recipe first
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
            // Fallback to home if recipe not found
            navigatorState.pushNamed('/home');
          }
        } catch (e) {
          debugPrint('Error fetching recipe for notification: $e');
          navigatorState.pushNamed('/home');
        }
        return;
      }

      // For routes that expect Map<String, String>, convert args
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

  // Handle initial URL scheme (for cold starts from share extension)
  void _handleInitialUrlScheme() {
    // This method will be enhanced with platform-specific URL handling
    // For now, we rely on the existing receive_sharing_intent mechanism
  }

  // Initialize share_handler to receive shared content
  Future<void> _initReceiveSharing() async {
    final handler = ShareHandlerPlatform.instance;

    // Get initial shared media when app launched from share
    final SharedMedia? initialMedia = await handler.getInitialSharedMedia();
    if (initialMedia != null) {
      final maybeUrl = _extractUrlFromSharedMedia(initialMedia);
      if (maybeUrl != null) {
        // Store the URL for SplashScreen to use
        _pendingSharedUrl = maybeUrl;
        _processedInitialUrl =
            maybeUrl; // Track this URL to prevent stream duplicates
        // Note: We don't navigate here anymore. SplashScreen will handle it.
      }
    }

    // Listen for media while app is in memory
    _mediaStreamSub = handler.sharedMediaStream.listen((SharedMedia media) {
      final maybeUrl = _extractUrlFromSharedMedia(media);
      if (maybeUrl != null) {
        // Skip if this is the same URL we already handled in cold start
        if (_processedInitialUrl == maybeUrl) {
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _handleSharedUrl(maybeUrl),
        );
      }
    });
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
          }
        });
      }
    });
  }

  // Internal static method to get and clear pending shared URL
  static String? _getPendingSharedUrl() {
    final url = _pendingSharedUrl;
    _pendingSharedUrl = null; // Clear after reading
    return url;
  }

  // Internal static method to get and clear pending notification payload
  static String? _getPendingNotificationPayload() {
    final payload = _pendingNotificationPayload;
    _pendingNotificationPayload = null; // Clear after reading
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
      // DEBUG: Restored Consumer2 but keeping MaterialApp static properties
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
              // Global dynamic background wrapper
              return AppTutorial(
                child: Consumer<DynamicUiProvider>(
                  builder: (context, dyn, _) {
                    final hasBg = dyn.config?.globalBackground != null;
                    final themedChild =
                        hasBg
                            ? Theme(
                              data: Theme.of(context).copyWith(
                                scaffoldBackgroundColor: Colors.transparent,
                              ),
                              child: Stack(
                                children: [
                                  const Positioned.fill(
                                    child: RepaintBoundary(
                                      child: DynamicGlobalBackground(),
                                    ),
                                  ),
                                  if (child != null) child,
                                ],
                              ),
                            )
                            : (child ?? const SizedBox.shrink());
                    return themedChild;
                  },
                ),
              );
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
                String? displayQuery;

                if (args is Map) {
                  try {
                    // Prioritize 'query' over 'tag' for backward compatibility
                    initialQuery =
                        (args['query'] as String?) ?? (args['tag'] as String?);
                    initialDifficulty = args['difficulty'] as String?;
                    displayQuery = args['displayQuery'] as String?;
                    // Don't use initialTag anymore - query is used instead
                    initialTag = null;
                  } catch (_) {
                    // ignore malformed args
                  }
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
              '/community': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                String? initialQuery;
                String? initialDifficulty;
                String? initialTag;
                String? displayQuery;

                if (args is Map) {
                  try {
                    initialQuery =
                        (args['query'] as String?) ?? (args['tag'] as String?);
                    initialDifficulty = args['difficulty'] as String?;
                    displayQuery = args['displayQuery'] as String?;
                    initialTag = null;
                  } catch (_) {
                    // ignore malformed args
                  }
                }

                return PersistentBannerLayout(
                  child: CommunityScreen(
                    initialQuery: initialQuery,
                    initialDifficulty: initialDifficulty,
                    initialTag: initialTag,
                    displayQuery: displayQuery,
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
              '/randomRecipe':
                  (context) =>
                      const PersistentBannerLayout(child: RandomRecipeScreen()),
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
