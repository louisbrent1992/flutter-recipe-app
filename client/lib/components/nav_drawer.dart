import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class NavDrawer extends StatefulWidget {
  const NavDrawer({super.key});

  @override
  State<NavDrawer> createState() => _NavDrawerState();
}

class _NavDrawerState extends State<NavDrawer> {
  final User? user = FirebaseAuth.instance.currentUser;
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            onDetailsPressed: () => Navigator.pushNamed(context, "/settings"),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              image: const DecorationImage(
                image: AssetImage('images/drawer_header_bg.jpg'),
                fit: BoxFit.cover,
                opacity: 0.7,
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              backgroundImage:
                  user?.photoURL != null
                      ? CachedNetworkImageProvider(user!.photoURL!)
                      : null,
              child:
                  user?.photoURL == null
                      ? Text(
                        user?.displayName?.isNotEmpty == true
                            ? user!.displayName![0].toUpperCase()
                            : 'R',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      )
                      : null,
            ),
            accountName: Text(
              user?.displayName ?? 'Recipe Enthusiast',
              style: theme.textTheme.titleLarge,
            ),
            accountEmail: Text(
              user?.email ?? '',
              style: theme.textTheme.titleSmall,
            ),
          ),
          Expanded(
            child: Scrollbar(
              controller: _scrollController,

              child: ListView(
                controller: _scrollController,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.home_rounded,
                    title: 'Home',
                    route: '/home',
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.person_rounded,
                    title: 'Profile',
                    route: '/settings',
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.restaurant_menu_rounded,
                    title: 'My Recipes',
                    route: '/myRecipes',
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.collections_bookmark_rounded,
                    title: 'Recipe Collections',
                    route: '/collections',
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.favorite_rounded,
                    title: 'Favorites',
                    route: '/favorites',
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 16.0,
                      top: 8.0,
                      bottom: 8.0,
                    ),
                    child: Text(
                      'Recipe Tools',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.add_box_rounded,
                    title: 'Import Recipe',
                    route: '/import',
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.auto_awesome_rounded,
                    title: 'Generate Recipe (Beta)',
                    route: '/generateRecipe',
                  ),
                  const Divider(),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.settings_rounded,
                    title: 'Settings',
                    route: '/settings',
                  ),
                ],
              ),
            ),
          ),
          // App version at the bottom
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            child: Text(
              'RecipEase v1.0.1',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String route,
  }) {
    final bool isActive = ModalRoute.of(context)?.settings.name == route;
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(icon, color: isActive ? theme.colorScheme.primary : null),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          color: isActive ? theme.colorScheme.primary : null,
        ),
      ),
      onTap: () {
        Navigator.pop(context); // Close the drawer
        if (!isActive) {
          Navigator.pushNamed(context, route);
        }
      },
      tileColor:
          isActive
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.2)
              : null,
      shape:
          isActive
              ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
              : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    );
  }
}
