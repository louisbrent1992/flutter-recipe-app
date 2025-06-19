import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipease/components/persistent_banner_layout.dart';
import 'package:recipease/firebase_options.dart';
import 'package:recipease/screens/my_recipes_screen.dart';
import 'package:recipease/screens/discover_recipes.dart';
import 'package:recipease/screens/favorite_recipes_screen.dart';
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
import 'screens/generated_recipes_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

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

  // Initialize Firebase first
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Activate app check after initialization, but before
  // usage of any Firebase services.
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
    webProvider: kIsWeb ? ReCaptchaV3Provider(kWebRecaptchaSiteKey) : null,
  );

  await Hive.initFlutter();
  await Hive.openBox('preferences');

  runApp(MyApp(Key('key')));
}

class MyApp extends StatefulWidget {
  const MyApp(Key? key) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ShareHandlerPlatform _shareHandler = ShareHandlerPlatform.instance;
  final PermissionService _permissionService = PermissionService();

  @override
  void initState() {
    super.initState();
    // Initialize share handler
    _initShareHandler();

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

  // Initialize the share handler to receive shared content
  Future<void> _initShareHandler() async {
    // Initial shared media
    final sharedMedia = await _shareHandler.getInitialSharedMedia();
    if (sharedMedia != null &&
        sharedMedia.content != null &&
        sharedMedia.content!.isNotEmpty) {
      print('Shared media received: ${sharedMedia.content}');
      _handleSharedMedia(sharedMedia);
    }

    // Register callback for future shared media
    _shareHandler.sharedMediaStream.listen(_handleSharedMedia);
  }

  // Handle the shared media
  void _handleSharedMedia(SharedMedia sharedMedia) {
    if (sharedMedia.content != null && sharedMedia.content!.isNotEmpty) {
      // Directly trigger import recipe function instead of navigating to import screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToImportScreen(sharedMedia.content!);
        _importRecipeFromSharedMedia(sharedMedia.content!);
      });
    }
  }

  // Import recipe directly from shared media
  void _importRecipeFromSharedMedia(String url) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      final recipeProvider = Provider.of<RecipeProvider>(
        context,
        listen: false,
      );
      recipeProvider.importRecipeFromUrl(url, context).then((recipe) {
        if (recipe != null && context.mounted) {
          // Navigate to recipe edit screen with the imported recipe
          Navigator.pushNamed(context, '/recipeEdit', arguments: recipe);
        }
      });
    }
  }

  // Navigate to the import screen with the shared URL (kept for manual import)
  void _navigateToImportScreen(String url) {
    navigatorKey.currentState?.pushNamed('/import', arguments: url);
  }

  @override
  void dispose() {
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
            title: 'Recipe App',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode:
                themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            debugShowCheckedModeBanner: kDebugMode ? true : false,
            home:
                authService.user != null
                    ? const PersistentBannerLayout(child: HomeScreen())
                    : const LoginScreen(),
            routes: {
              '/home': (context) => const HomeScreen(),
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/discover':
                  (context) => const PersistentBannerLayout(
                    child: DiscoverRecipesScreen(),
                  ),
              '/favorites':
                  (context) => const PersistentBannerLayout(
                    child: FavoriteRecipesScreen(),
                  ),
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
