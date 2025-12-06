import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../config/app_config.dart';
import '../services/recipe_service.dart';
import '../main.dart';
import '../providers/recipe_provider.dart';
import '../services/collection_service.dart';
import '../providers/dynamic_ui_provider.dart';
import '../providers/user_profile_provider.dart'; // REQUIRED FOR PROFILE/CREDITS LOAD

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Use configuration for splash duration

  bool _isInitializationComplete = false;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();

    // Initialize app and wait for minimum duration
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Wait for Firebase Auth to initialize
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!mounted) return;
    final userProfileProvider = Provider.of<UserProfileProvider>(
      context,
      listen: false,
    );

    // Collect futures to wait for
    final List<Future<void>> preloadFutures = [];

    // --- CRITICAL FIX: LOAD PROFILE/CREDITS IF LOGGED IN ---
    if (authService.user != null) {
      // Explicitly load profile (contains credits) and add to preload queue
      preloadFutures.add(userProfileProvider.loadProfile());
      preloadFutures.add(_preloadHomeScreenData());
    }
    // -------------------------------------------------------

    // Wait for minimum splash duration
    final elapsed = DateTime.now().difference(_startTime!);
    final remainingTime =
        AppConfig.splashMinDurationMs - elapsed.inMilliseconds;

    if (remainingTime > 0) {
      await Future.delayed(Duration(milliseconds: remainingTime));
    }

    // Wait for all preload data (profile + recipes) to complete (with timeout)
    if (preloadFutures.isNotEmpty) {
      try {
        await Future.wait(preloadFutures).timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint(
              'Preload/Profile load timeout - proceeding with navigation',
            );
            return <void>[];
          },
        );
      } catch (e) {
        debugPrint(
          'Preload/Profile load error - proceeding with navigation: $e',
        );
      }
    }

    // Mark initialization as complete
    if (mounted) {
      setState(() {
        _isInitializationComplete = true;
      });
    }

    // Wait a bit more for smooth transition
    await Future.delayed(
      Duration(milliseconds: AppConfig.splashTransitionDelayMs),
    );

    // Navigate to appropriate screen
    if (mounted) {
      _navigateToNextScreen();
    }
  }

  /// Preloads home screen data and dynamic UI during splash screen
  /// This allows the home screen to appear instantly with data already loaded
  Future<void> _preloadHomeScreenData() async {
    try {
      // Access providers without listening (we're just preloading)
      final recipeProvider = Provider.of<RecipeProvider>(
        context,
        listen: false,
      );
      final collectionService = Provider.of<CollectionService>(
        context,
        listen: false,
      );
      final dynamicUiProvider = Provider.of<DynamicUiProvider>(
        context,
        listen: false,
      );

      // Load all data in parallel and wait for completion
      await Future.wait([
        recipeProvider.loadUserRecipes(limit: 20),
        collectionService.getCollections(updateSpecialCollections: true),
        recipeProvider.fetchSessionDiscoverCache(),
        dynamicUiProvider.refresh(), // Preload dynamic UI config
      ]);

      // After cache loads, preload carousel data
      if (mounted) {
        final discover = recipeProvider.getFilteredDiscoverRecipes(
          page: 1,
          limit: 50,
        );
        recipeProvider.setGeneratedRecipesFromCache(discover);
      }
    } catch (e) {
      debugPrint('Error preloading home screen data: $e');
      // Don't throw - preload failures shouldn't block navigation
    }
  }

  Future<void> _navigateToNextScreen() async {
    final authService = Provider.of<AuthService>(context, listen: false);

    // Check if there's a pending shared URL from cold start
    final pendingUrl = getPendingSharedUrl();

    // Check if there's a pending notification from cold start
    final pendingNotification = getPendingNotificationPayload();

    final isAuthenticated = authService.user != null;

    if (!isAuthenticated) {
      // --- CRITICAL FIX: REDIRECT TO LOGIN IF UNAUTHENTICATED ---
      // If an import was attempted, pass the URL as a redirect argument.
      if (pendingUrl != null) {
        // Assuming your /login screen handles a Map argument to set a redirect.
        // This is a common pattern for deep link authentication.
        Navigator.pushReplacementNamed(
          context,
          '/login',
          arguments: {'redirectRoute': '/import', 'url': pendingUrl},
        );
        return;
      }

      // Default unauthenticated launch -> Go to Login screen
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    // --- User IS AUTHENTICATED from here ---

    if (pendingUrl != null) {
      // Authenticated + Share link -> Go directly to Import.
      Navigator.pushReplacementNamed(context, '/import', arguments: pendingUrl);
      return;
    }

    if (pendingNotification != null) {
      // If we have a notification, navigate to the notification route
      try {
        final obj = jsonDecode(pendingNotification) as Map<String, dynamic>;
        final route = obj['route'] as String?;
        final args = obj['args'] as Map<String, dynamic>?;

        if (route != null && route.isNotEmpty) {
          // Special handling for recipeDetail - need to fetch recipe first
          if (route == '/recipeDetail' &&
              args != null &&
              args['recipeId'] != null) {
            final recipeId = args['recipeId'] as String;
            try {
              final response = await RecipeService.getRecipeById(recipeId);
              if (response.success && response.data != null && mounted) {
                Navigator.pushReplacementNamed(
                  context,
                  '/recipeDetail',
                  arguments: response.data,
                );
                return;
              }
            } catch (e) {
              debugPrint('Error fetching recipe from notification: $e');
            }
            // Fallback to home if recipe fetch fails
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/home');
            }
            return;
          }

          // Convert args to Map<String, String> if needed for other routes
          Map<String, String>? stringArgs;
          if (args != null && args.isNotEmpty) {
            stringArgs = args.map(
              (key, value) => MapEntry(key, value?.toString() ?? ''),
            );
          }

          Navigator.pushReplacementNamed(
            context,
            route,
            arguments: stringArgs ?? args,
          );
          return;
        }
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
        // Fall through to default navigation
      }
    }

    // Default navigation
    if (authService.user != null) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: Container(
        color: Colors.transparent,
        child: Center(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            'assets/icons/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              // Fallback if logo not found
                              return Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Icon(
                                  Icons.restaurant_menu,
                                  size: 60,
                                  color: colorScheme.onPrimary,
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // App name
                      Text(
                        'RecipEase',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          letterSpacing: 1.2,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Tagline
                      Text(
                        'Your Personal Cooking Assistant',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                          letterSpacing: 0.5,
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Loading indicator
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Loading text
                      Text(
                        _isInitializationComplete
                            ? 'Almost ready...'
                            : 'Loading...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
