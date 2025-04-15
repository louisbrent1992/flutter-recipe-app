import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipease/providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import '../components/custom_app_bar.dart';
import '../components/nav_drawer.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final User? userData = ModalRoute.of(context)!.settings.arguments as User?;

    // Check if userData is null and navigate to login if necessary
    if (context.read<AuthService>().user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
      return Container(); // Return an empty container while redirecting
    }

    print('User ID: ${userData?.uid}');

    return Scaffold(
      appBar: const CustomAppBar(title: 'recipease'),
      drawer: const NavDrawer(),
      body: SafeArea(
        child: Consumer<UserProfileProvider>(
          builder: (context, profile, _) {
            if (profile.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Welcome, ${userData?.displayName ?? 'User'}!',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                _buildSection(
                  context,
                  'My Recipes',
                  Icons.restaurant_menu,
                  () => Navigator.pushNamed(context, '/myRecipes'),
                ),
                const SizedBox(height: 16),
                _buildSection(
                  context,
                  'Discover Recipes',
                  Icons.explore,
                  () => Navigator.pushNamed(context, '/discover'),
                ),
                const SizedBox(height: 16),
                _buildSection(
                  context,
                  'Favorite Recipes',
                  Icons.favorite,
                  () => Navigator.pushNamed(context, '/favorites'),
                ),
                const SizedBox(height: 16),
                _buildSection(
                  context,
                  'Import Recipe',
                  Icons.add_circle_outline,
                  () => Navigator.pushNamed(context, '/import'),
                ),
                const SizedBox(height: 16),
                _buildSection(
                  context,
                  'Generate Recipe',
                  Icons.auto_awesome,
                  () => Navigator.pushNamed(context, '/generate'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title, style: Theme.of(context).textTheme.titleLarge),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
