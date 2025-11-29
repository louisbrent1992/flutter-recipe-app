import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../config/app_config.dart';
import '../services/recipe_service.dart';
import '../main.dart';

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
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
      ),
    );

    _animationController.forward();

    // Initialize app and wait for minimum duration
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Wait for Firebase Auth to initialize
    // This ensures we have the correct auth state before navigation
    // Give Firebase Auth time to restore session if user was previously logged in
    await Future.delayed(const Duration(milliseconds: 500));

    // Wait for minimum splash duration
    final elapsed = DateTime.now().difference(_startTime!);
    final remainingTime =
        AppConfig.splashMinDurationMs - elapsed.inMilliseconds;

    if (remainingTime > 0) {
      await Future.delayed(Duration(milliseconds: remainingTime));
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

  Future<void> _navigateToNextScreen() async {
    final authService = Provider.of<AuthService>(context, listen: false);

    // Check if there's a pending shared URL from cold start
    final pendingUrl = getPendingSharedUrl();

    // Check if there's a pending notification from cold start
    final pendingNotification = getPendingNotificationPayload();

    if (pendingUrl != null) {
      // If we have a shared URL, navigate directly to import screen
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
          if (route == '/recipeDetail' && args != null && args['recipeId'] != null) {
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
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
