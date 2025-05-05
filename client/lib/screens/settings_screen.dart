import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipease/providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/notification_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

  void _toggleEditing() {
    setState(() => _isEditing = !_isEditing);
    if (_isEditing) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        actions: [
          if (_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.cancel_outlined),
              onPressed: _toggleEditing,
              tooltip: 'Cancel editing',
            ),
            IconButton(
              icon: const Icon(Icons.save_outlined),
              onPressed: _updateProfile,
              tooltip: 'Save changes',
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _toggleEditing,
              tooltip: 'Edit profile',
            ),
          ],
        ],
      ),
      body: Consumer<UserProfileProvider>(
        builder: (context, profile, _) {
          if (profile.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.surface,
                  colorScheme.surface.withValues(alpha: 0.8),
                ],
              ),
            ),
            child: Scrollbar(
              controller: _scrollController,
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  // Profile Header
                  _buildProfileHeader(profile, colorScheme),

                  const SizedBox(height: 32),

                  // Profile Fields
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    padding: EdgeInsets.all(_isEditing ? 16 : 0),
                    decoration: BoxDecoration(
                      color:
                          _isEditing
                              ? colorScheme.primaryContainer.withValues(
                                alpha: 0.3,
                              )
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isEditing)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Edit Profile',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                        _buildAnimatedTextField(
                          controller: _nameController,
                          enabled: _isEditing,
                          label: 'Display Name',
                          hint: user?.displayName ?? 'Your name',
                          icon: Icons.person_rounded,
                        ),

                        const SizedBox(height: 16),

                        _buildAnimatedTextField(
                          controller: _emailController,
                          enabled: _isEditing,
                          label: 'Email',
                          hint: user?.email ?? 'Your email',
                          icon: Icons.email_rounded,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Appearance Section
                  _buildSectionHeader(
                    title: 'Appearance',
                    icon: Icons.palette_outlined,
                    colorScheme: colorScheme,
                  ),

                  const SizedBox(height: 16),

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
                                ? Colors.indigo
                                : Colors.amber,
                      );
                    },
                  ),

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Notifications Section
                  _buildSectionHeader(
                    title: 'Notifications',
                    icon: Icons.notifications_outlined,
                    colorScheme: colorScheme,
                  ),

                  const SizedBox(height: 16),

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
                            color: Colors.teal,
                          ),

                          const SizedBox(height: 8),

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

                          const SizedBox(height: 8),

                          _buildAnimatedSwitchTile(
                            title: 'New Recipes',
                            subtitle: 'Get notified about new recipes',
                            value: notificationProvider.newRecipesNotification,
                            onChanged:
                                (value) => notificationProvider
                                    .setNewRecipesNotification(value),
                            icon: Icons.restaurant_rounded,
                            color: Colors.orange,
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Links Section
                  _buildSectionHeader(
                    title: 'Quick Links',
                    icon: Icons.link_rounded,
                    colorScheme: colorScheme,
                  ),

                  const SizedBox(height: 16),

                  _buildAnimatedListTile(
                    title: 'Favorite Recipes',
                    icon: Icons.favorite_rounded,
                    color: Colors.red,
                    onTap: () => Navigator.pushNamed(context, '/favorites'),
                  ),

                  const SizedBox(height: 12),

                  _buildAnimatedListTile(
                    title: 'Sign Out',
                    icon: Icons.logout_rounded,
                    color: Colors.grey.shade600,
                    onTap: _signOut,
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(
    UserProfileProvider profile,
    ColorScheme colorScheme,
  ) {
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
                        profile.profile['photoURL'] != null
                            ? CachedNetworkImageProvider(
                              profile.profile['photoURL'],
                            )
                            : null,
                    child:
                        profile.profile['photoURL'] == null
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
                  elevation: 4,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.hardEdge,
                  child: InkWell(
                    onTap: _uploadProfilePicture,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        size: 20,
                        color: colorScheme.onSecondary,
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
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            user?.email ?? '',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
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
        Icon(icon, color: colorScheme.primary, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
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
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: TextField(
        controller: controller,
        enabled: enabled,
        style: TextStyle(
          fontSize: 16,
          fontWeight: enabled ? FontWeight.normal : FontWeight.bold,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: enabled ? const BorderSide() : BorderSide.none,
          ),
          filled: !enabled,
          fillColor:
              enabled
                  ? Colors.transparent
                  : Theme.of(context).colorScheme.surface,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
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
        color: value ? color.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: value ? color : Theme.of(context).colorScheme.onSurface,
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
                    ? color.withValues(alpha: 0.1)
                    : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color:
                value
                    ? color
                    : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        activeColor: color,
      ),
    );
  }

  Widget _buildAnimatedListTile({
    required String title,
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
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
