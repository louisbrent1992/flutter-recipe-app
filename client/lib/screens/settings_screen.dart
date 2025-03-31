import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: SafeArea(
        child: Scrollbar(
          thumbVisibility: true,
          thickness: 10,
          controller: _scrollController,
          child: ListView(
            controller: _scrollController,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  shape: BoxShape.rectangle,
                  color: Theme.of(context).colorScheme.surface,
                ),
                width: double.infinity,
                child: Column(
                  children: [
                    _buildSettingsItem('Account', Icons.person, '/profile'),
                    const Divider(color: Color.fromARGB(16, 0, 0, 0)),
                    _buildSettingsItem(
                      'My subscription',
                      Icons.subscriptions,
                      '/subscription',
                    ),
                  ],
                ),
              ),

              const Divider(color: Color.fromARGB(16, 0, 0, 0)),
              Container(
                padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  shape: BoxShape.rectangle,
                  color: Theme.of(context).colorScheme.surface,
                ),

                width: double.infinity,
                child: Column(
                  children: [
                    _buildSettingsItem(
                      'General settings',
                      Icons.settings,
                      '/general_settings',
                    ),
                    const Divider(color: Color.fromARGB(16, 0, 0, 0)),
                    _buildSettingsItem(
                      'Privacy settings',
                      Icons.privacy_tip,
                      '/privacy_settings',
                    ),
                    const Divider(color: Color.fromARGB(16, 0, 0, 0)),
                    _buildSettingsItem(
                      'Notification settings',
                      Icons.notifications,
                      '/notification_settings',
                    ),
                    const Divider(color: Color.fromARGB(16, 0, 0, 0)),
                    _buildSettingsItem(
                      'Appearance settings',
                      Icons.color_lens,
                      '/appearance_settings',
                    ),
                    const Divider(color: Color.fromARGB(16, 0, 0, 0)),
                    _buildSettingsItem(
                      'Advanced settings',
                      Icons.build,
                      '/advanced_settings',
                    ),
                  ],
                ),
              ),
              const Divider(color: Color.fromARGB(16, 0, 0, 0)),
              Container(
                padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  shape: BoxShape.rectangle,
                  color: Theme.of(context).colorScheme.surface,
                ),

                width: double.infinity,

                child: Column(
                  children: [
                    _buildSettingsItem(
                      'Help & Support',
                      Icons.help,
                      '/help_support',
                    ),
                    const Divider(color: Color.fromARGB(16, 0, 0, 0)),
                    _buildSettingsItem('Sign out', Icons.logout, '/sign_out'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsItem(String title, IconData icon, String routeName) {
    return ListTile(
      title: Text(title),
      leading: Icon(icon),
      trailing: const Icon(Icons.arrow_forward),

      onTap: () {
        Navigator.pushNamed(context, routeName);
        // Handle navigation or action
      },
    );
  }
}
