import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildSettingsItem('Account', Icons.person),
            _buildSettingsItem('My subscription', Icons.subscriptions),
            const Divider(),
            _buildSettingsItem('General settings', Icons.settings),
            _buildSettingsItem('Privacy settings', Icons.privacy_tip),
            _buildSettingsItem('Notification settings', Icons.notifications),
            _buildSettingsItem('Appearance settings', Icons.color_lens),
            _buildSettingsItem('Advanced settings', Icons.build),
            const Divider(),
            _buildSettingsItem('Help & Support', Icons.help),
            _buildSettingsItem('Sign out', Icons.logout),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem(String title, IconData icon) {
    return ListTile(
      title: Text(title),
      leading: Icon(icon),
      trailing: const Icon(Icons.arrow_forward),
      onTap: () {
        // Handle navigation or action
      },
    );
  }
}
