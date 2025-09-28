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
import '../components/floating_bottom_bar.dart';
import '../services/bulk_image_refresh_service.dart';
import '../models/recipe.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

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
    });
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

    _nameController.text = profile.profile['displayName'] ?? '';
    _emailController.text = profile.profile['email'] ?? '';
  }

  Future<void> _updateProfile() async {
    final profile = context.read<UserProfileProvider>();
    try {
      await profile.updateProfile(
        displayName: _nameController.text,
        email: _emailController.text,
      );
      if (mounted) {
        setState(() => _isEditing = false);
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
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
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
            content: Text('Error uploading profile picture: $e'),
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
    setState(() => _isEditing = !_isEditing);
    if (_isEditing) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
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
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: AppElevation.appBar,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
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
          ] else ...[
            IconButton(
              icon: const Icon(Icons.edit_note_rounded),
              onPressed: _toggleEditing,
              tooltip: 'Edit profile',
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.responsive(context),
                AppSpacing.responsive(context),
                AppSpacing.responsive(context),
                30,
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
                          label: 'Recipe Name:',
                          hint: user?.displayName ?? 'Your name',
                          icon: Icons.person_rounded,
                        ),

                        SizedBox(height: AppSpacing.md),

                        _buildAnimatedTextField(
                          controller: _emailController,
                          enabled: _isEditing,
                          label: 'Email:',
                          hint: user?.email ?? 'Your email',
                          icon: Icons.email_rounded,
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

                  // Notifications Section
                  _buildSectionHeader(
                    title: 'Notifications',
                    icon: Icons.notifications_rounded,
                    colorScheme: colorScheme,
                  ),

                  SizedBox(height: AppSpacing.md),

                  Consumer<NotificationProvider>(
                    builder: (context, notificationProvider, _) {
                      return Column(
                        children: [
                          _buildAnimatedSwitchTile(
                            title: 'Daily Recipe Reminder',
                            subtitle: 'Get a recipe suggestion every day',
                            value: notificationProvider.dailyRecipeReminder,
                            onChanged:
                                (value) => notificationProvider
                                    .setDailyRecipeReminder(value),
                            icon: Icons.schedule_rounded,
                            color: Theme.of(context).colorScheme.info,
                          ),

                          SizedBox(height: AppSpacing.sm),

                          _buildAnimatedSwitchTile(
                            title: 'Weekly Digest',
                            subtitle: 'Receive a weekly summary of new recipes',
                            value: notificationProvider.weeklyDigest,
                            onChanged:
                                (value) =>
                                    notificationProvider.setWeeklyDigest(value),
                            icon: Icons.summarize_rounded,
                            color: Colors.purple,
                          ),

                          SizedBox(height: AppSpacing.sm),

                          _buildAnimatedSwitchTile(
                            title: 'New Recipes',
                            subtitle: 'Get notified about new recipes',
                            value: notificationProvider.newRecipesNotification,
                            onChanged:
                                (value) => notificationProvider
                                    .setNewRecipesNotification(value),
                            icon: Icons.restaurant_menu_rounded,
                            color: theme.colorScheme.onTertiary,
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
                            () => Navigator.pushNamed(context, '/subscription'),
                      );
                    },
                  ),

                  SizedBox(height: AppSpacing.xxl),
                  const Divider(height: 1, thickness: 0.1),
                  SizedBox(height: AppSpacing.md),

                  // Links Section
                  _buildSectionHeader(
                    title: 'Quick Links',
                    icon: Icons.restaurant_menu_rounded,
                    colorScheme: colorScheme,
                  ),

                  SizedBox(height: AppSpacing.md),
                  _buildAnimatedListTile(
                    title: 'My Recipes',
                    subtitle: 'Explore your recipes',
                    icon: Icons.restaurant_menu_rounded,
                    color: Theme.of(context).colorScheme.warning,
                    onTap: () => Navigator.pushNamed(context, '/myRecipes'),
                  ),
                  // Favorites removed
                  SizedBox(height: AppSpacing.md),
                  _buildAnimatedListTile(
                    title: 'Discover Recipes',
                    subtitle: 'Find new recipe ideas',
                    icon: Icons.explore,
                    color: Colors.blue,
                    onTap: () => Navigator.pushNamed(context, '/discover'),
                  ),

                  // Only show image refresh in production mode
                  if (!kDebugMode) ...[
                    SizedBox(height: AppSpacing.md),
                    _buildImageRefreshTile(colorScheme),
                  ],

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

                  SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),

          FloatingBottomBar(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(ColorScheme colorScheme) {
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
                    backgroundImage:
                        user?.photoURL != null
                            ? CachedNetworkImageProvider(user!.photoURL!)
                            : null,
                    child:
                        user?.photoURL == null
                            ? Icon(
                              Icons.person_rounded,
                              size: 60,
                              color: Colors.grey[400],
                            )
                            : null,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Material(
                  elevation: AppElevation.button,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.hardEdge,
                  child: InkWell(
                    onTap: _uploadProfilePicture,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error.withValues(
                          alpha: Theme.of(context).colorScheme.overlayMedium,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        size: 20,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(
                          alpha: Theme.of(context).colorScheme.alphaHigh,
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
              enabled: enabled,
              style: TextStyle(
                fontSize: AppTypography.responsiveFontSize(context),
                fontWeight: enabled ? FontWeight.normal : FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: hint,
                prefixIcon: Icon(icon),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppBreakpoints.isMobile(context) ? 8 : 12,
                  ),
                  borderSide: enabled ? const BorderSide() : BorderSide.none,
                ),
                filled: !enabled,
                fillColor:
                    enabled
                        ? Colors.transparent
                        : Theme.of(context).colorScheme.surface,
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
