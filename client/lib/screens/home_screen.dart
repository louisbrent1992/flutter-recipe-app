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

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  final String username =
      FirebaseAuth.instance.currentUser?.displayName ?? 'User';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Check if userData is null and navigate to login if necessary
    if (context.read<AuthService>().user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
      return Container(); // Return an empty container while redirecting
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'RecipEase', useLogo: true),
      drawer: const NavDrawer(),
      body: SafeArea(
        child: Consumer<UserProfileProvider>(
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
                thumbVisibility: true,
                thickness: 10,
                controller: _scrollController,
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: colorScheme.primaryContainer.withValues(
                          alpha: 0.3,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome,',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          Text(
                            username,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'What would you like to cook today?',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildAnimatedSection(
                      context: context,
                      title: 'My Recipes',
                      icon: Icons.restaurant_menu,
                      onTap: () => Navigator.pushNamed(context, '/myRecipes'),
                      delay: 0.1,
                      description: 'Access your saved recipes',
                      color: Colors.orange.withValues(alpha: 0.2),
                      iconColor: Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    _buildAnimatedSection(
                      context: context,
                      title: 'Recipe Collections',
                      icon: Icons.collections_bookmark_rounded,
                      onTap: () => Navigator.pushNamed(context, '/collections'),
                      delay: 0.15,
                      description: 'Organize recipes into categories',
                      color: Colors.purple.withValues(alpha: 0.2),
                      iconColor: Colors.purple,
                    ),
                    const SizedBox(height: 16),
                    _buildAnimatedSection(
                      context: context,
                      title: 'Discover Recipes',
                      icon: Icons.explore,
                      onTap: () => Navigator.pushNamed(context, '/discover'),
                      delay: 0.2,
                      description: 'Find new recipes to try',
                      color: Colors.blue.withValues(alpha: 0.2),
                      iconColor: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    _buildAnimatedSection(
                      context: context,
                      title: 'Favorite Recipes',
                      icon: Icons.favorite,
                      onTap: () => Navigator.pushNamed(context, '/favorites'),
                      delay: 0.3,
                      description: 'Browse your favorite recipes',
                      color: Colors.red.withValues(alpha: 0.2),
                      iconColor: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    _buildAnimatedSection(
                      context: context,
                      title: 'Import Recipe',
                      icon: Icons.add_circle_outline,
                      onTap: () => Navigator.pushNamed(context, '/import'),
                      delay: 0.4,
                      description: 'Import recipes from websites',
                      color: Colors.green.withValues(alpha: 0.2),
                      iconColor: Colors.green,
                    ),
                    const SizedBox(height: 16),
                    _buildAnimatedSection(
                      context: context,
                      title: 'Generate Recipe',
                      icon: Icons.auto_awesome,
                      onTap: () => Navigator.pushNamed(context, '/generate'),
                      delay: 0.5,
                      description: 'Create new recipes with AI',
                      color: Colors.purple.withValues(alpha: 0.2),
                      iconColor: Colors.purple,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAnimatedSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required double delay,
    required String description,
    required Color color,
    required Color iconColor,
  }) {
    final animation = CurvedAnimation(
      parent: _animationController,
      curve: Interval(delay, delay + 0.4, curve: Curves.easeOut),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - animation.value)),
          child: Opacity(opacity: animation.value, child: child),
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: color,
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 28, color: iconColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
