import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipease/providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/subscription_provider.dart';
import '../theme/theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/custom_app_bar.dart';
import '../services/bulk_image_refresh_service.dart';
import '../models/recipe.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../services/image_resolver_cache.dart';
import '../utils/image_utils.dart';
import '../services/notification_scheduler.dart';
import '../services/debug_settings.dart';
import '../services/tutorial_service.dart';
import '../components/app_tutorial.dart';
import '../main.dart' show navigatorKey;
import '../providers/recipe_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isEditing = false;
  bool _isRefreshingImages = false;
  final User? user = FirebaseAuth.instance.currentUser;
  late AnimationController _animationController;
  final ScrollController _scrollController = ScrollController();

  // Debug settings
  bool _debugFeaturesEnabled = false;
  final _debugSettings = DebugSettings();

  // Store original values when entering edit mode
  String? _originalName;
  String? _originalEmail;

  // Helper method to check if user signed in with OAuth provider
  bool _isOAuthUser(User? user) {
    if (user == null) return false;

    // Check providerData for OAuth providers
    final providers = user.providerData.map((info) => info.providerId).toList();

    return providers.contains('google.com') || providers.contains('apple.com');
  }

  // Get the provider name for display
  String? _getProviderName(User? user) {
    if (user == null) return null;

    final providers = user.providerData.map((info) => info.providerId).toList();

    if (providers.contains('google.com')) return 'Google';
    if (providers.contains('apple.com')) return 'Apple';
    return null;
  }

  // Get provider icon
  IconData? _getProviderIcon(User? user) {
    if (user == null) return null;

    final providers = user.providerData.map((info) => info.providerId).toList();

    if (providers.contains('google.com')) return Icons.g_mobiledata_rounded;
    if (providers.contains('apple.com')) return Icons.apple_rounded;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // Schedule the profile loading for the next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
      _loadDebugSettings();
    });
  }

  Future<void> _loadDebugSettings() async {
    if (!kDebugMode) return;
    await _debugSettings.init();
    if (mounted) {
      setState(() {
        _debugFeaturesEnabled = _debugSettings.isDebugEnabled;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;

    final profile = context.read<UserProfileProvider>();
    await profile.loadProfile();

    if (!mounted) return;

    // Only update controllers if not currently editing (to avoid overwriting user input)
    if (!_isEditing) {
      _nameController.text = profile.profile['displayName'] ?? '';
      _emailController.text = profile.profile['email'] ?? '';
    }
  }

  /// Formats Firebase auth errors into user-friendly messages
  String _formatAuthError(dynamic error) {
    final errorString = error.toString();

    if (errorString.contains('requires-recent-login')) {
      return 'For security, please sign out and sign back in to update your profile.';
    } else if (errorString.contains('email-already-in-use')) {
      return 'This email is already in use by another account.';
    } else if (errorString.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    } else if (errorString.contains('weak-password')) {
      return 'Password is too weak. Please choose a stronger password.';
    } else if (errorString.contains('user-not-found')) {
      return 'User account not found. Please sign in again.';
    } else if (errorString.contains('wrong-password')) {
      return 'Incorrect password. Please try again.';
    } else if (errorString.contains('network-request-failed')) {
      return 'Network error. Please check your internet connection and try again.';
    } else if (errorString.contains('too-many-requests')) {
      return 'Too many requests. Please wait a moment and try again.';
    } else if (errorString.contains('operation-not-allowed')) {
      return 'This operation is not allowed. Please contact support.';
    }

    // Default: return a generic friendly message
    return 'Unable to update profile. Please try again or contact support if the problem persists.';
  }

  Future<void> _updateProfile() async {
    final profile = context.read<UserProfileProvider>();
    try {
      // Email editing is disabled for all users - only update display name
      await profile.updateProfile(
        displayName: _nameController.text,
        email: null, // Never update email
      );
      if (mounted) {
        setState(() {
          _isEditing = false;
          _originalName = null;
          _originalEmail = null;
        });
        _animationController.reverse();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_formatAuthError(e)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _uploadProfilePicture() async {
    final profile = context.read<UserProfileProvider>();
    try {
      await profile.uploadProfilePicture();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile picture updated successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_formatAuthError(e)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteProfilePicture() async {
    final profile = context.read<UserProfileProvider>();
    final photoURL = profile.profile['photoURL'] as String? ?? user?.photoURL;

    // Check if user has a custom photo (not the default)
    final hasCustomPhoto =
        photoURL != null &&
        photoURL != ImageUtils.defaultProfileIconUrl &&
        photoURL.isNotEmpty;

    if (!hasCustomPhoto) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No custom profile picture to delete'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Profile Picture'),
            content: const Text(
              'Are you sure you want to delete your profile picture? This will restore the default icon.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      await profile.deleteProfilePicture();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile picture deleted successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_formatAuthError(e)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _triggerTestNotification(
    AppNotificationCategory category,
  ) async {
    try {
      // Trigger notification and get route info
      final routeInfo = await NotificationScheduler.triggerTestNotification(
        category,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test notification triggered!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Also navigate directly since notification tap might not work in foreground
        if (routeInfo != null) {
          final route = routeInfo['route'] as String?;
          final args = routeInfo['args'] as Map<String, String>?;

          if (route != null && route.isNotEmpty) {
            // Wait a moment for the notification to show, then navigate
            Future.delayed(const Duration(milliseconds: 500), () {
              if (navigatorKey.currentState != null) {
                navigatorKey.currentState!.pushNamed(route, arguments: args);
              } else {
                // If navigator not ready, try again after a frame
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (navigatorKey.currentState != null) {
                    navigatorKey.currentState!.pushNamed(
                      route,
                      arguments: args,
                    );
                  }
                });
              }
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error triggering notification: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _restartTutorial() async {
    try {
      final tutorialService = TutorialService();
      
      // Reset tutorial completion status with manual flag
      await tutorialService.resetTutorial(isManual: true);

      if (mounted) {
        // Navigate to home screen
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);

        // Use frame callbacks to wait for widgets to be built instead of arbitrary delays
        // This ensures smooth transition without stuttering
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Wait one more frame to ensure all widgets are fully rendered
          WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigatorKey.currentContext != null) {
              final homeContext = navigatorKey.currentContext!;
              final recipeProvider = Provider.of<RecipeProvider>(
                homeContext,
                listen: false,
              );
              
              // Start with navigation drawer menu and credit balance (most important UI elements)
              final List<GlobalKey> tutorialTargets = [
                TutorialKeys.navDrawerMenu,
                TutorialKeys.creditBalance,
              ];

              // Then add home hero section
              tutorialTargets.add(TutorialKeys.homeHero);

              // Only include "Your Recipes" if the user has saved recipes
              if (recipeProvider.userRecipes.isNotEmpty) {
                tutorialTargets.add(TutorialKeys.homeYourRecipes);
              }

              // Only include "Discover" if there are random recipes to show
              final randomRecipes =
                  recipeProvider.generatedRecipes
                      .where(
                        (r) => !recipeProvider.userRecipes.any((u) => u.id == r.id),
                      )
                      .take(10)
                      .toList();

              if (randomRecipes.isNotEmpty) {
                tutorialTargets.add(TutorialKeys.homeDiscover);
              }

              // Collections are always shown (even if empty state), so safe to include
              tutorialTargets.add(TutorialKeys.homeCollections);

              // Add Features section
              tutorialTargets.add(TutorialKeys.homeFeatures);

              // Add bottom navigation targets
              tutorialTargets.addAll([
                TutorialKeys.bottomNavHome,
                TutorialKeys.bottomNavDiscover,
                TutorialKeys.bottomNavMyRecipes,
                TutorialKeys.bottomNavGenerate,
                TutorialKeys.bottomNavSettings,
          ]);

              // Start tutorial immediately after widgets are built
              startTutorial(homeContext, tutorialTargets);
            }
          });
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tutorial started! 👋'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting tutorial: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final auth = context.read<AuthService>();
    try {
      await auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.warning_rounded,
                color: Colors.red,
                size: AppSizing.responsiveIconSize(
                  context,
                  mobile: 24,
                  tablet: 28,
                  desktop: 32,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Text(
                'Delete Account',
                style: TextStyle(
                  fontSize: AppTypography.responsiveHeadingSize(
                    context,
                    mobile: 18.0,
                    tablet: 20.0,
                    desktop: 22.0,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to permanently delete your account?',
                style: TextStyle(
                  fontSize: AppTypography.responsiveFontSize(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: AppSpacing.md),
              Container(
                padding: EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error.withValues(
                    alpha: Theme.of(context).colorScheme.overlayMedium,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppBreakpoints.isMobile(context) ? 6 : 8,
                  ),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.error.withValues(
                      alpha: Theme.of(context).colorScheme.alphaMedium,
                    ),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This action will permanently delete:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700,
                        fontSize: AppTypography.responsiveFontSize(context),
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      '• Your account and profile',
                      style: TextStyle(
                        fontSize: AppTypography.responsiveFontSize(context),
                      ),
                    ),
                    Text(
                      '• All your saved recipes',
                      style: TextStyle(
                        fontSize: AppTypography.responsiveFontSize(context),
                      ),
                    ),
                    Text(
                      '• Your recipe collections',
                      style: TextStyle(
                        fontSize: AppTypography.responsiveFontSize(context),
                      ),
                    ),
                    Text(
                      '• All app preferences and data',
                      style: TextStyle(
                        fontSize: AppTypography.responsiveFontSize(context),
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      'This action cannot be undone.',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700,
                        fontSize: AppTypography.responsiveFontSize(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Delete Account'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await _deleteAccount();
    }
  }

  Future<void> _deleteAccount() async {
    final auth = context.read<AuthService>();

    // Store the navigator and scaffold messenger to avoid context issues
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Deleting account...'),
              ],
            ),
          );
        },
      );

      await auth.deleteAccount();

      // Close loading dialog first
      if (mounted) {
        navigator.pop();
      }

      // Small delay to ensure auth state has updated
      await Future.delayed(const Duration(milliseconds: 100));

      // Navigate to login screen and clear all routes
      if (mounted) {
        navigator.pushNamedAndRemoveUntil('/login', (route) => false);
      }

      // Show success message after navigation
      await Future.delayed(const Duration(milliseconds: 500));

      // Use a post-frame callback to ensure the login screen is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.onSuccess,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Account deleted successfully. Thank you for using RecipEase!',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      });
    } catch (e) {
      if (mounted) {
        // Close loading dialog
        navigator.pop();

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Theme.of(context).colorScheme.onError),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error deleting account: $e',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _toggleEditing() {
    setState(() {
      if (_isEditing) {
        // Canceling - restore original values
        if (_originalName != null) {
          _nameController.text = _originalName!;
        }
        if (_originalEmail != null) {
          _emailController.text = _originalEmail!;
        }
        _originalName = null;
        _originalEmail = null;
        _isEditing = false;
        _animationController.reverse();
      } else {
        // Entering edit mode - save current values
        _originalName = _nameController.text;
        // Email editing is disabled for all users
        _isEditing = true;
        _animationController.forward();
      }
    });
  }

  String? encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map(
          (MapEntry<String, String> e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Settings',
        elevation: AppElevation.appBar,
        actions: [
          if (_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.cancel_rounded),
              onPressed: _toggleEditing,
              tooltip: 'Cancel editing',
            ),
            IconButton(
              icon: const Icon(Icons.save_rounded),
              onPressed: _updateProfile,
              tooltip: 'Save changes',
            ),
          ],
        ],
        floatingButtons: [
          // Context menu
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: Icon(
              Icons.more_vert,
              size: AppSizing.responsiveIconSize(
                context,
                mobile: 24,
                tablet: 28,
                desktop: 30,
              ),
            ),
            color: Theme.of(context).colorScheme.surface.withValues(
              alpha: Theme.of(context).colorScheme.alphaVeryHigh,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outline.withValues(
                  alpha: Theme.of(context).colorScheme.overlayLight,
                ),
                width: 1,
              ),
            ),
            onSelected: (value) async {
              switch (value) {
                case 'edit_profile':
                  _toggleEditing();
                  break;
                case 'upload_picture':
                  await _uploadProfilePicture();
                  break;
                case 'delete_picture':
                  await _deleteProfilePicture();
                  break;
                case 'refresh':
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  await _loadProfile();
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: const Text('Profile refreshed'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }
                  break;
                case 'my_recipes':
                  Navigator.pushNamed(context, '/myRecipes');
                  break;
                case 'discover':
                  Navigator.pushNamed(context, '/discover');
                  break;
                case 'logout':
                  await _signOut();
                  break;
              }
            },
            itemBuilder: (context) {
              final profileProvider = context.read<UserProfileProvider>();
              final photoURL =
                  profileProvider.profile['photoURL'] as String? ??
                  user?.photoURL;
              final hasCustomPhoto =
                  photoURL != null &&
                  photoURL != ImageUtils.defaultProfileIconUrl &&
                  photoURL.isNotEmpty;

              final items = <PopupMenuEntry<String>>[];

              // Edit Profile
              items.add(
                PopupMenuItem<String>(
                  value: 'edit_profile',
                  child: Row(
                    children: [
                      Icon(
                        _isEditing ? Icons.edit_off : Icons.edit,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(_isEditing ? 'Stop Editing' : 'Edit Profile'),
                    ],
                  ),
                ),
              );

              // Upload Profile Picture
              items.add(
                PopupMenuItem<String>(
                  value: 'upload_picture',
                  child: Row(
                    children: [
                      Icon(
                        Icons.camera_alt_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text('Upload Picture'),
                    ],
                  ),
                ),
              );

              // Delete Profile Picture (only if custom photo exists)
              if (hasCustomPhoto) {
                items.add(
                  PopupMenuItem<String>(
                    value: 'delete_picture',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Delete Picture',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Refresh Profile
              items.add(
                PopupMenuItem<String>(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(
                        Icons.refresh,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text('Refresh Profile'),
                    ],
                  ),
                ),
              );

              // Divider
              items.add(const PopupMenuDivider());

              // Quick Navigation
              items.add(
                PopupMenuItem<String>(
                  value: 'my_recipes',
                  child: Row(
                    children: [
                      Icon(
                        Icons.restaurant_menu_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text('My Recipes'),
                    ],
                  ),
                ),
              );

              items.add(
                PopupMenuItem<String>(
                  value: 'discover',
                  child: Row(
                    children: [
                      Icon(
                        Icons.explore,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text('Discover'),
                    ],
                  ),
                ),
              );

              // Divider before logout
              items.add(const PopupMenuDivider());

              // Logout
              items.add(
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        size: 18,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Sign Out',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              );

              return items;
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth:
                      AppBreakpoints.isDesktop(context)
                          ? 800
                          : AppBreakpoints.isTablet(context)
                          ? 700
                          : double.infinity,
                ),
                padding: EdgeInsets.only(
                  left: AppSpacing.responsive(context),
                  right: AppSpacing.responsive(context),
                  top: AppSpacing.responsive(context),
                  bottom: AppSpacing.responsive(context) + 30, // Extra space for floating bar
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header
                    _buildProfileHeader(colorScheme),

                    SizedBox(height: AppSpacing.xxl),

                    // Profile Fields
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      padding: EdgeInsets.all(_isEditing ? AppSpacing.md : 0),
                      decoration: BoxDecoration(
                        color:
                            _isEditing
                                ? colorScheme.primaryContainer.withValues(
                                  alpha: 0.3,
                                )
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(
                          AppBreakpoints.isMobile(context) ? 12 : 16,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isEditing)
                            Padding(
                              padding: EdgeInsets.only(bottom: AppSpacing.md),
                              child: Text(
                                'Edit Profile',
                                style: TextStyle(
                                  fontSize: AppTypography.responsiveHeadingSize(
                                    context,
                                    mobile: 20.0,
                                    tablet: 24.0,
                                    desktop: 28.0,
                                  ),
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                          _buildAnimatedTextField(
                            controller: _nameController,
                            enabled: _isEditing,
                            label: 'Name:',
                            hint: user?.displayName ?? 'Your name',
                            icon: Icons.person_rounded,
                          ),

                          SizedBox(height: AppSpacing.md),

                          // Email field - read-only for all users
                          _buildReadOnlyEmailField(
                            email: user?.email ?? '',
                            providerName:
                                _isOAuthUser(user)
                                    ? (_getProviderName(user) ?? 'Provider')
                                    : 'Email',
                            providerIcon:
                                _isOAuthUser(user)
                                    ? _getProviderIcon(user)
                                    : Icons.email_rounded,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: AppSpacing.xxl),
                    const Divider(height: 1, thickness: 0.1),
                    SizedBox(height: AppSpacing.md),

                    // Appearance Section
                    _buildSectionHeader(
                      title: 'Appearance',
                      icon: Icons.palette_rounded,
                      colorScheme: colorScheme,
                    ),

                    SizedBox(height: AppSpacing.md),

                    Consumer<ThemeProvider>(
                      builder: (context, themeProvider, _) {
                        return _buildAnimatedSwitchTile(
                          title: 'Dark Mode',
                          subtitle: 'Switch between light and dark themes',
                          value: themeProvider.isDarkMode,
                          onChanged: (value) => themeProvider.toggleTheme(),
                          icon:
                              themeProvider.isDarkMode
                                  ? Icons.dark_mode_rounded
                                  : Icons.light_mode_rounded,
                          color:
                              themeProvider.isDarkMode
                                  ? Theme.of(context).colorScheme.info
                                  : Theme.of(context).colorScheme.warning,
                        );
                      },
                    ),

                    SizedBox(height: AppSpacing.md),
                    const Divider(height: 1, thickness: 0.1),
                    SizedBox(height: AppSpacing.md),

                    // Category Notifications Section
                    _buildSectionHeader(
                      title: 'Category Notifications',
                      icon: Icons.notifications_rounded,
                      colorScheme: colorScheme,
                    ),

                    SizedBox(height: AppSpacing.sm),

                    Consumer<NotificationProvider>(
                      builder: (context, notificationProvider, _) {
                        return Column(
                          children: [
                            _buildAnimatedSwitchTile(
                              title: 'Daily Inspiration',
                              subtitle: 'Receive a daily pick at 9:00 AM',
                              value: notificationProvider.catDailyInspiration,
                              onChanged:
                                  (v) => notificationProvider
                                      .setCatDailyInspiration(v),
                              icon: Icons.lightbulb_rounded,
                              color: Colors.orange,
                            ),

                            SizedBox(height: AppSpacing.sm),

                            _buildAnimatedSwitchTile(
                              title: 'Meal Prep Sunday',
                              subtitle: 'Weekly reminder Sundays 5:00 PM',
                              value: notificationProvider.catMealPrep,
                              onChanged:
                                  (v) => notificationProvider.setCatMealPrep(v),
                              icon: Icons.calendar_month_rounded,
                              color: Colors.teal,
                            ),

                            SizedBox(height: AppSpacing.sm),

                            _buildAnimatedSwitchTile(
                              title: 'Seasonal Collections',
                              subtitle: 'Weekly Friday highlights at 12:00 PM',
                              value: notificationProvider.catSeasonal,
                              onChanged:
                                  (v) => notificationProvider.setCatSeasonal(v),
                              icon: Icons.snowing,
                              color: Colors.redAccent,
                            ),

                            SizedBox(height: AppSpacing.sm),

                            _buildAnimatedSwitchTile(
                              title: 'Quick Meals',
                              subtitle: 'Weekly Tuesdays at 6:00 PM',
                              value: notificationProvider.catQuickMeals,
                              onChanged:
                                  (v) =>
                                      notificationProvider.setCatQuickMeals(v),
                              icon: Icons.flash_on_rounded,
                              color: Colors.amber,
                            ),

                            SizedBox(height: AppSpacing.sm),

                            _buildAnimatedSwitchTile(
                              title: 'Budget-Friendly',
                              subtitle: 'Weekly Wednesdays at 6:00 PM',
                              value: notificationProvider.catBudget,
                              onChanged:
                                  (v) => notificationProvider.setCatBudget(v),
                              icon: Icons.attach_money_rounded,
                              color: Colors.green,
                            ),

                            SizedBox(height: AppSpacing.sm),

                            _buildAnimatedSwitchTile(
                              title: 'Keto Spotlight',
                              subtitle: 'Weekly Mondays at 12:00 PM',
                              value: notificationProvider.catKeto,
                              onChanged:
                                  (v) => notificationProvider.setCatKeto(v),
                              icon: Icons.restaurant_rounded,
                              color: Colors.blue,
                            ),
                          ],
                        );
                      },
                    ),

                    SizedBox(height: AppSpacing.xxl),
                    const Divider(height: 1, thickness: 0.1),
                    SizedBox(height: AppSpacing.md),

                    // Premium Features Section
                    _buildSectionHeader(
                      title: 'Premium Features',
                      icon: Icons.star_rounded,
                      colorScheme: colorScheme,
                    ),
                    SizedBox(height: AppSpacing.md),
                    Consumer<SubscriptionProvider>(
                      builder: (context, subscriptionProvider, _) {
                        return _buildAnimatedListTile(
                          title:
                              subscriptionProvider.isPremium
                                  ? 'Premium Active'
                                  : 'Upgrade to Premium',
                          subtitle:
                              subscriptionProvider.isPremium
                                  ? 'Enjoy all premium features'
                                  : 'Remove ads and unlock premium features',
                          icon:
                              subscriptionProvider.isPremium
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                          color:
                              subscriptionProvider.isPremium
                                  ? Theme.of(context).colorScheme.warning
                                  : colorScheme.primary,
                          onTap:
                              () =>
                                  Navigator.pushNamed(context, '/subscription'),
                        );
                      },
                    ),

                    SizedBox(height: AppSpacing.xxl),
                    const Divider(height: 1, thickness: 0.1),
                    SizedBox(height: AppSpacing.md),

                    // Features Section
                    _buildSectionHeader(
                      title: 'Features',
                      icon: Icons.restaurant_menu_rounded,
                      colorScheme: colorScheme,
                    ),

                    SizedBox(height: AppSpacing.md),
                    _buildAnimatedListTile(
                      title: 'Import Recipes',
                      subtitle: 'Paste a link to import a recipe',
                      icon: Icons.link_rounded,
                      color: Theme.of(context).colorScheme.info,
                      onTap: () => Navigator.pushNamed(context, '/import'),
                    ),

                    SizedBox(height: AppSpacing.md),
                    _buildAnimatedListTile(
                      title: 'Generate Recipes',
                      subtitle: 'Create recipes from your ingredients',
                      icon: Icons.auto_awesome_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      onTap: () => Navigator.pushNamed(context, '/generate'),
                    ),

                    SizedBox(height: AppSpacing.md),
                    _buildAnimatedListTile(
                      title: 'My Recipes',
                      subtitle: 'Explore your recipes',
                      icon: Icons.restaurant_menu_rounded,
                      color: Theme.of(context).colorScheme.warning,
                      onTap: () => Navigator.pushNamed(context, '/myRecipes'),
                    ),

                    SizedBox(height: AppSpacing.md),
                    _buildAnimatedListTile(
                      title: 'Discover Recipes',
                      subtitle: 'Find new recipe ideas',
                      icon: Icons.explore,
                      color: Colors.blue,
                      onTap: () => Navigator.pushNamed(context, '/discover'),
                    ),

                    SizedBox(height: AppSpacing.md),
                    _buildAnimatedListTile(
                      title: 'App Tutorial',
                      subtitle: 'Learn how to use RecipEase',
                      icon: Icons.help_outline_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      onTap: _restartTutorial,
                    ),

                    SizedBox(height: AppSpacing.xxl),
                    const Divider(height: 1, thickness: 0.1),
                    SizedBox(height: AppSpacing.md),
                    // Contact Section
                    _buildSectionHeader(
                      title: 'Contact Us',
                      icon: Icons.contact_support_rounded,
                      colorScheme: colorScheme,
                    ),
                    SizedBox(height: AppSpacing.md),

                    // Support Inquiries
                    _buildAnimatedListTile(
                      title: 'Customer Support',
                      subtitle: 'Get help with app issues',
                      icon: Icons.support_agent_rounded,
                      color: colorScheme.primary,
                      onTap: () async {
                        final Uri emailLaunchUri = Uri(
                          scheme: 'mailto',
                          path: 'support@recipease.kitchen',
                          query: encodeQueryParameters({
                            'subject': 'Customer Support - RecipEase',
                            'body':
                                'Hi RecipEase Support Team,\n\nI need help with...\n\nThank you!\n',
                          }),
                        );
                        if (await canLaunchUrl(emailLaunchUri)) {
                          await launchUrl(emailLaunchUri);
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Could not launch email client'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                    ),

                    SizedBox(height: AppSpacing.md),

                    // General Inquiries
                    _buildAnimatedListTile(
                      title: 'General Inquiries',
                      subtitle: 'Questions about RecipEase',
                      icon: Icons.help_outline_rounded,
                      color: Colors.blue,
                      onTap: () async {
                        final Uri emailLaunchUri = Uri(
                          scheme: 'mailto',
                          path: 'hello@recipease.kitchen',
                          query: encodeQueryParameters({
                            'subject': 'General Inquiry - RecipEase',
                            'body':
                                'Hello RecipEase Team,\n\nI would like to know...\n\nThank you!\n',
                          }),
                        );
                        if (await canLaunchUrl(emailLaunchUri)) {
                          await launchUrl(emailLaunchUri);
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Could not launch email client'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                    ),

                    SizedBox(height: AppSpacing.md),

                    // Billing Support
                    _buildAnimatedListTile(
                      title: 'Billing Support',
                      subtitle: 'Payments and invoices',
                      icon: Icons.payment_rounded,
                      color: Theme.of(context).colorScheme.success,
                      onTap: () async {
                        final Uri emailLaunchUri = Uri(
                          scheme: 'mailto',
                          path: 'billing@adventhubsolutions.com',
                          query: encodeQueryParameters({
                            'subject': 'Billing Inquiry - RecipEase',
                            'body':
                                'Hello Billing Team,\n\nI have a question about...\n\nThank you!\n',
                          }),
                        );
                        if (await canLaunchUrl(emailLaunchUri)) {
                          await launchUrl(emailLaunchUri);
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Could not launch email client'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                    ),

                    SizedBox(height: AppSpacing.md),

                    // Business Inquiries
                    _buildAnimatedListTile(
                      title: 'Business Inquiries',
                      subtitle: 'Partnerships and collaborations',
                      icon: Icons.business_rounded,
                      color: Colors.purple,
                      onTap: () async {
                        final Uri emailLaunchUri = Uri(
                          scheme: 'mailto',
                          path: 'partnerships@adventhubsolutions.com',
                          query: encodeQueryParameters({
                            'subject': 'Business Inquiry - RecipEase',
                            'body':
                                'Hello Business Team,\n\nI am interested in...\n\nThank you!\n',
                          }),
                        );
                        if (await canLaunchUrl(emailLaunchUri)) {
                          await launchUrl(emailLaunchUri);
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Could not launch email client'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    SizedBox(height: AppSpacing.xxl),

                    const Divider(height: 1, thickness: 0.1),
                    SizedBox(height: AppSpacing.md),

                    // Links Section
                    _buildSectionHeader(
                      title: 'Account Management',
                      icon: Icons.person_rounded,
                      colorScheme: colorScheme,
                    ),

                    SizedBox(height: AppSpacing.md),

                    _buildAnimatedListTile(
                      title: 'Sign Out',
                      icon: Icons.logout_rounded,
                      color: Colors.grey.shade600,
                      onTap: _signOut,
                    ),

                    SizedBox(height: AppSpacing.md),

                    _buildAnimatedListTile(
                      title: 'Delete Account',
                      subtitle: 'Permanently delete your account and all data',
                      icon: Icons.delete_forever_rounded,
                      color: Colors.red,
                      onTap: _showDeleteAccountDialog,
                    ),

                    // Debug Section (only in debug mode)
                    if (kDebugMode) ...[
                      SizedBox(height: AppSpacing.xxl),
                      const Divider(height: 1, thickness: 0.1),
                      SizedBox(height: AppSpacing.md),

                      // Debug Features Toggle
                      _buildAnimatedSwitchTile(
                        title: 'Enable Debug Features',
                        subtitle: 'Show debug-only features like Refresh Image',
                        value: _debugFeaturesEnabled,
                        onChanged: (value) async {
                          if (!mounted) return;
                          final messenger = ScaffoldMessenger.of(context);
                          await _debugSettings.setDebugEnabled(value);
                          if (!mounted) return;
                          setState(() {
                            _debugFeaturesEnabled = value;
                          });
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                value
                                    ? 'Debug features enabled'
                                    : 'Debug features disabled',
                              ),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: Icons.developer_mode_rounded,
                        color: Colors.deepPurple,
                      ),

                      // Show Developer Tools section only when debug features enabled
                      if (_debugFeaturesEnabled) ...[
                        SizedBox(height: AppSpacing.md),
                        const Divider(height: 1, thickness: 0.1),
                        SizedBox(height: AppSpacing.md),

                        _buildSectionHeader(
                          title: 'Developer Tools',
                          icon: Icons.code_rounded,
                          colorScheme: colorScheme,
                        ),

                        SizedBox(height: AppSpacing.md),

                        // Bulk Image Refresh
                        _buildImageRefreshTile(colorScheme),

                        SizedBox(height: AppSpacing.sm),

                        // Clear Image Cache
                        _buildAnimatedListTile(
                          title: 'Clear Image Cache',
                          subtitle:
                              'Remove cached image resolutions to force fresh fetch',
                          icon: Icons.delete_sweep_rounded,
                          color: colorScheme.error,
                          onTap: () async {
                            final removed = await ImageResolverCache.clearAll();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Cleared $removed cached images',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                        ),

                        SizedBox(height: AppSpacing.md),
                        const Divider(height: 1, thickness: 0.1),
                        SizedBox(height: AppSpacing.sm),

                        // Notification Tests Section Header
                        Text(
                          'Test Notifications',
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        SizedBox(height: AppSpacing.sm),

                        _buildAnimatedListTile(
                          title: 'Test Daily Inspiration',
                          subtitle:
                              'Trigger the daily inspiration notification',
                          icon: Icons.notifications_active_rounded,
                          color: colorScheme.primary,
                          onTap:
                              () => _triggerTestNotification(
                                AppNotificationCategory.dailyInspiration,
                              ),
                        ),

                        SizedBox(height: AppSpacing.sm),

                        _buildAnimatedListTile(
                          title: 'Test Meal Prep',
                          subtitle: 'Trigger the meal prep notification',
                          icon: Icons.lunch_dining_rounded,
                          color: colorScheme.primary,
                          onTap:
                              () => _triggerTestNotification(
                                AppNotificationCategory.mealPrep,
                              ),
                        ),

                        SizedBox(height: AppSpacing.sm),

                        _buildAnimatedListTile(
                          title: 'Test Seasonal',
                          subtitle: 'Trigger the seasonal notification',
                          icon: Icons.celebration_rounded,
                          color: colorScheme.primary,
                          onTap:
                              () => _triggerTestNotification(
                                AppNotificationCategory.seasonal,
                              ),
                        ),

                        SizedBox(height: AppSpacing.sm),

                        _buildAnimatedListTile(
                          title: 'Test Quick Meals',
                          subtitle: 'Trigger the quick meals notification',
                          icon: Icons.timer_rounded,
                          color: colorScheme.primary,
                          onTap:
                              () => _triggerTestNotification(
                                AppNotificationCategory.quickMeals,
                              ),
                        ),

                        SizedBox(height: AppSpacing.sm),

                        _buildAnimatedListTile(
                          title: 'Test Budget',
                          subtitle: 'Trigger the budget notification',
                          icon: Icons.savings_rounded,
                          color: colorScheme.primary,
                          onTap:
                              () => _triggerTestNotification(
                                AppNotificationCategory.budget,
                              ),
                        ),

                        SizedBox(height: AppSpacing.sm),

                        _buildAnimatedListTile(
                          title: 'Test Keto',
                          subtitle: 'Trigger the keto notification',
                          icon: Icons.local_dining_rounded,
                          color: colorScheme.primary,
                          onTap:
                              () => _triggerTestNotification(
                                AppNotificationCategory.keto,
                              ),
                        ),
                      ],
                    ],

                    SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(ColorScheme colorScheme) {
    return Consumer<UserProfileProvider>(
      builder: (context, profileProvider, _) {
        final photoURL =
            profileProvider.profile['photoURL'] as String? ??
            user?.photoURL ??
            ImageUtils.defaultProfileIconUrl;

        return Center(
          child: Column(
            children: [
              Stack(
                children: [
                  Hero(
                    tag: 'profile_picture',
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [colorScheme.primary, colorScheme.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: CachedNetworkImageProvider(photoURL),
                      ),
                    ),
                  ),
                  // Loading overlay
                  if (profileProvider.isLoading)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Camera button (upload)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Material(
                      elevation: AppElevation.button,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.hardEdge,
                      child: InkWell(
                        onTap:
                            profileProvider.isLoading
                                ? null
                                : _uploadProfilePicture,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(
                              alpha:
                                  Theme.of(context).colorScheme.overlayMedium,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            size: 20,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(
                              alpha:
                                  profileProvider.isLoading
                                      ? Theme.of(context).colorScheme.alphaLow
                                      : Theme.of(context).colorScheme.alphaHigh,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                user?.displayName ?? 'Recipe Enthusiast',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                user?.email ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(
                    alpha: Theme.of(context).colorScheme.alphaHigh,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required ColorScheme colorScheme,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
          size: 22,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedTextField({
    required TextEditingController controller,
    required bool enabled,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      margin: EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              label,
              style: TextStyle(
                fontSize: AppTypography.responsiveFontSize(context),
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: TextField(
              controller: controller,
              enabled: true,
              style: TextStyle(
                fontSize: AppTypography.responsiveFontSize(context),
                fontWeight: FontWeight.normal,
              ),
              decoration: InputDecoration(
                hintText: hint,
                prefixIcon: Icon(icon),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppBreakpoints.isMobile(context) ? 8 : 12,
                  ),
                  borderSide: const BorderSide(),
                ),
                filled: false,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppBreakpoints.isMobile(context) ? 8 : 12,
                  ),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                contentPadding: AppSpacing.allResponsive(context),
              ),
              onTap: () {
                if (!_isEditing) {
                  setState(() => _isEditing = true);
                  _animationController.forward();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyEmailField({
    required String email,
    required String providerName,
    IconData? providerIcon,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isOAuth = _isOAuthUser(user);

    return Container(
      margin: EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'Email:',
              style: TextStyle(
                fontSize: AppTypography.responsiveFontSize(context),
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          Container(
            padding: AppSpacing.allResponsive(context),
            decoration: BoxDecoration(
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(
                AppBreakpoints.isMobile(context) ? 8 : 12,
              ),
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
            child: Row(
              children: [
                Icon(
                  providerIcon ?? Icons.email_rounded,
                  color:
                      isOAuth
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                  size: AppSizing.responsiveIconSize(
                    context,
                    mobile: 20,
                    tablet: 22,
                    desktop: 24,
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: AppTypography.responsiveFontSize(context),
                          fontWeight: FontWeight.normal,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (isOAuth) ...[
                        SizedBox(height: AppSpacing.xs / 2),
                        Text(
                          'Signed in with $providerName',
                          style: TextStyle(
                            fontSize:
                                AppTypography.responsiveFontSize(context) *
                                0.85,
                            color: colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.lock_rounded,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  size: AppSizing.responsiveIconSize(
                    context,
                    mobile: 16,
                    tablet: 18,
                    desktop: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    required Color color,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color:
            value
                ? color.withValues(
                  alpha: Theme.of(context).colorScheme.alphaLow,
                )
                : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color:
                value
                    ? color
                    : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:
                value
                    ? color.withValues(
                      alpha: Theme.of(context).colorScheme.alphaMedium,
                    )
                    : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color:
                value
                    ? color
                    : Theme.of(context).colorScheme.onSurface.withValues(
                      alpha: Theme.of(context).colorScheme.alphaHigh,
                    ),
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        activeThumbColor: color,
      ),
    );
  }

  Widget _buildAnimatedListTile({
    required String title,
    String? subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(
              alpha: Theme.of(context).colorScheme.alphaLow,
            ),

            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(
                    alpha: Theme.of(context).colorScheme.alphaMedium,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(
                            alpha: Theme.of(context).colorScheme.alphaHigh,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the image refresh tile (production only)
  Widget _buildImageRefreshTile(ColorScheme colorScheme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _isRefreshingImages ? null : _refreshAllImages,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color:
                _isRefreshingImages
                    ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                    : Colors.green.withValues(
                      alpha: Theme.of(context).colorScheme.alphaLow,
                    ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      _isRefreshingImages
                          ? colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          )
                          : Colors.green.withValues(
                            alpha: Theme.of(context).colorScheme.alphaMedium,
                          ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    _isRefreshingImages
                        ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colorScheme.primary,
                            ),
                          ),
                        )
                        : Icon(
                          Icons.refresh_rounded,
                          color: Colors.green,
                          size: 24,
                        ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isRefreshingImages
                          ? 'Refreshing Images...'
                          : 'Fix Broken Images',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color:
                            _isRefreshingImages
                                ? colorScheme.onSurface.withValues(alpha: 0.6)
                                : Colors.green,
                      ),
                    ),
                    if (!_isRefreshingImages)
                      Text(
                        'Update broken recipe images in your collection',
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows progress dialog and performs bulk image refresh
  Future<void> _refreshAllImages() async {
    // Prevent multiple concurrent refreshes
    if (_isRefreshingImages) return;

    try {
      setState(() => _isRefreshingImages = true);

      // Get all user recipes
      final allRecipes = await BulkImageRefreshService.getAllUserRecipes();

      if (allRecipes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No saved recipes found to refresh images for.'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      if (mounted) {
        await _showImageRefreshDialog(allRecipes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading recipes: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshingImages = false);
      }
    }
  }

  /// Shows the progress dialog for image refresh
  Future<void> _showImageRefreshDialog(List<Recipe> recipes) async {
    int currentProgress = 0;
    String currentRecipe = '';
    bool isCompleted = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Start the bulk refresh process when dialog opens
            if (!isCompleted && currentProgress == 0) {
              Future.delayed(Duration(milliseconds: 100), () async {
                await BulkImageRefreshService.refreshAllBrokenImages(
                  recipes,
                  onProgress: (current, total, recipeTitle) {
                    setDialogState(() {
                      currentProgress = current;
                      currentRecipe = recipeTitle ?? '';
                    });
                  },
                  onCompletion: (totalFixed, totalChecked) {
                    setDialogState(() {
                      isCompleted = true;
                    });

                    // Close the progress dialog
                    Navigator.of(dialogContext).pop();

                    // Show completion dialog
                    _showCompletionDialog(totalFixed, totalChecked);
                  },
                );
              });
            }

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.refresh_rounded, color: Colors.green, size: 24),
                  SizedBox(width: 12),
                  Text('Refreshing Images'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Processing recipe images...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 16),
                  LinearProgressIndicator(
                    value:
                        recipes.isEmpty ? 0 : currentProgress / recipes.length,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '$currentProgress of ${recipes.length} recipes checked',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  if (currentRecipe.isNotEmpty) ...[
                    SizedBox(height: 8),
                    Text(
                      'Current: $currentRecipe',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Shows completion dialog with results
  Future<void> _showCompletionDialog(int totalFixed, int totalChecked) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                totalFixed > 0 ? Icons.check_circle : Icons.info,
                color: totalFixed > 0 ? Colors.green : Colors.blue,
                size: 24,
              ),
              SizedBox(width: 12),
              Text('Image Refresh Complete'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                totalFixed > 0
                    ? 'Successfully refreshed $totalFixed broken images!'
                    : 'No broken images were found in your recipe collection.',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Checked $totalChecked recipes total.',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
