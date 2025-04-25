import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:recipease/screens/my_recipes_screen.dart';
import 'package:recipease/screens/discover_recipes.dart';
import 'package:recipease/screens/favorite_recipes_screen.dart';
import 'package:recipease/screens/generate_recipe_screen.dart';
import 'package:recipease/screens/home_screen.dart';
import 'package:recipease/screens/recipe_edit_screen.dart';
import 'package:recipease/screens/import_list.dart';
import 'package:recipease/screens/import_recipe_screen.dart';
import 'package:recipease/screens/recipe_detail_screen.dart';
import 'package:recipease/screens/settings_screen.dart';
import 'package:recipease/screens/auth/login_screen.dart';
import 'package:recipease/screens/auth/register_screen.dart';
import 'package:recipease/screens/recipe_collection_screen.dart';
import 'package:recipease/screens/collection_detail_screen.dart';
import 'package:recipease/theme/theme.dart';
import 'package:recipease/providers/auth_provider.dart';
import 'package:recipease/providers/user_profile_provider.dart';
import 'package:recipease/providers/theme_provider.dart';
import 'package:recipease/providers/notification_provider.dart';
import 'package:recipease/providers/recipe_provider.dart';
import 'package:recipease/models/recipe.dart';
import 'package:recipease/models/recipe_collection.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_handler/share_handler.dart';
import 'package:share_handler_platform_interface/share_handler_platform_interface.dart';
import 'package:recipease/services/permission_service.dart';
import 'services/firebase_options.dart';
import 'screens/generated_recipes_screen.dart';
import 'screens/imported_recipes_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Initializes the app.
///
/// Ensures Flutter is bound to the widgets layer, initializes Firebase, and
/// loads the app's preferences from local storage. Then, runs the app with
/// the loaded preferences.
///
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('preferences');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
    if (sharedMedia != null) {
      print('Shared media received: ${sharedMedia.content}');
      _handleSharedMedia(sharedMedia);
    }

    // Register callback for future shared media
    _shareHandler.sharedMediaStream.listen(_handleSharedMedia);
  }

  // Handle the shared media
  void _handleSharedMedia(SharedMedia sharedMedia) {
    if (sharedMedia.content != null && sharedMedia.content!.isNotEmpty) {
      // Navigate to import screen with URL
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToImportScreen(sharedMedia.content!);
      });
    }
  }

  // Navigate to the import screen with the shared URL
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
            debugShowCheckedModeBanner: false,
            home:
                authService.user != null
                    ? const HomeScreen()
                    : const LoginScreen(),
            routes: {
              '/home': (context) => const HomeScreen(),
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/discover': (context) => const DiscoverRecipesScreen(),
              '/favorites': (context) => const FavoriteRecipesScreen(),
              '/generate': (context) => const GenerateRecipeScreen(),
              '/import':
                  (context) => ImportRecipeScreen(
                    sharedUrl:
                        ModalRoute.of(context)?.settings.arguments as String?,
                  ),
              '/importList': (context) => const ImportListScreen(),
              '/recipeEdit': (context) => const RecipeEditScreen(),
              '/myRecipes': (context) => const MyRecipesScreen(),
              '/recipeDetail':
                  (context) => RecipeDetailScreen(
                    recipe:
                        ModalRoute.of(context)!.settings.arguments as Recipe?,
                  ),
              '/settings': (context) => const SettingsScreen(),
              '/collections': (context) => const RecipeCollectionScreen(),
              '/collectionDetail':
                  (context) => CollectionDetailScreen(
                    collection:
                        ModalRoute.of(context)!.settings.arguments
                            as RecipeCollection,
                  ),
              '/generatedRecipes': (context) => const GeneratedRecipesScreen(),
              '/importedRecipes': (context) => const ImportedRecipesScreen(),
            },
          );
        },
      ),
    );
  }
}
