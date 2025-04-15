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

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = context.read<UserProfileProvider>();
    await profile.loadProfile();
    if (mounted) {
      setState(() {
        _nameController.text = profile.profile['displayName'] ?? '';
        _emailController.text = profile.profile['email'] ?? '';
      });
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
      }
    }
  }

  Future<void> _uploadProfilePicture() async {
    final profile = context.read<UserProfileProvider>();
    try {
      await profile.uploadProfilePicture();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading profile picture: $e')),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (_isEditing)
            IconButton(icon: const Icon(Icons.save), onPressed: _updateProfile)
          else
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: Consumer<UserProfileProvider>(
        builder: (context, profile, _) {
          if (profile.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage:
                          profile.profile['photoURL'] != null
                              ? CachedNetworkImageProvider(
                                profile.profile['photoURL'],
                              )
                              : null,
                      child:
                          profile.profile['photoURL'] == null
                              ? const Icon(Icons.person, size: 50)
                              : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, size: 20),
                          color: Theme.of(context).colorScheme.onPrimary,
                          onPressed: _uploadProfilePicture,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                enabled: _isEditing,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                enabled: _isEditing,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) {
                  return SwitchListTile(
                    title: const Text('Dark Mode'),
                    value: themeProvider.isDarkMode,
                    onChanged: (value) => themeProvider.toggleTheme(),
                  );
                },
              ),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Notifications',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Consumer<NotificationProvider>(
                builder: (context, notificationProvider, _) {
                  return Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Daily Recipe Reminder'),
                        subtitle: const Text(
                          'Get a recipe suggestion every day',
                        ),
                        value: notificationProvider.dailyRecipeReminder,
                        onChanged:
                            (value) => notificationProvider
                                .setDailyRecipeReminder(value),
                      ),
                      SwitchListTile(
                        title: const Text('Weekly Digest'),
                        subtitle: const Text(
                          'Receive a weekly summary of new recipes',
                        ),
                        value: notificationProvider.weeklyDigest,
                        onChanged:
                            (value) =>
                                notificationProvider.setWeeklyDigest(value),
                      ),
                      SwitchListTile(
                        title: const Text('New Recipes'),
                        subtitle: const Text('Get notified about new recipes'),
                        value: notificationProvider.newRecipesNotification,
                        onChanged:
                            (value) => notificationProvider
                                .setNewRecipesNotification(value),
                      ),
                    ],
                  );
                },
              ),
              const Divider(),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.favorite),
                title: const Text('Favorite Recipes'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/favorites'),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign Out'),
                onTap: _signOut,
              ),
            ],
          );
        },
      ),
    );
  }
}
