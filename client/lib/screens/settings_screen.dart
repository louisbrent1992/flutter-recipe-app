import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),

        child: ListView(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                shape: BoxShape.rectangle,
                color: Colors.teal[100],
              ),
              width: double.infinity,
              child: Column(
                children: [
                  _buildSettingsItem('Account', Icons.person, '/profile'),
                  const Divider(color: Color.fromARGB(14, 0, 0, 0)),
                  _buildSettingsItem(
                    'My subscription',
                    Icons.subscriptions,
                    '/subscription',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                shape: BoxShape.rectangle,
                color: Colors.teal[100],
              ),

              width: double.infinity,
              child: Column(
                children: [
                  _buildSettingsItem(
                    'General settings',
                    Icons.settings,
                    '/general_settings',
                  ),
                  const Divider(color: Color.fromARGB(14, 0, 0, 0)),
                  _buildSettingsItem(
                    'Privacy settings',
                    Icons.privacy_tip,
                    '/privacy_settings',
                  ),
                  const Divider(color: Color.fromARGB(14, 0, 0, 0)),
                  _buildSettingsItem(
                    'Notification settings',
                    Icons.notifications,
                    '/notification_settings',
                  ),
                  const Divider(color: Color.fromARGB(14, 0, 0, 0)),
                  _buildSettingsItem(
                    'Appearance settings',
                    Icons.color_lens,
                    '/appearance_settings',
                  ),
                  const Divider(color: Color.fromARGB(14, 0, 0, 0)),
                  _buildSettingsItem(
                    'Advanced settings',
                    Icons.build,
                    '/advanced_settings',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                shape: BoxShape.rectangle,
                color: Colors.teal[100],
              ),

              width: double.infinity,

              child: Column(
                children: [
                  _buildSettingsItem(
                    'Help & Support',
                    Icons.help,
                    '/help_support',
                  ),
                  const Divider(color: Color.fromARGB(14, 0, 0, 0)),
                  _buildSettingsItem('Sign out', Icons.logout, '/sign_out'),
                ],
              ),
            ),
          ],
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
