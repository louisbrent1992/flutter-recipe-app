import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart'; // Import app_links package

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final AppLinks _appLinks = AppLinks(); // Create an instance of AppLinks

  @override
  void initState() {
    super.initState();
    _initAppLinks();
  }

  Future<void> _initAppLinks() async {
    // Get the initial link
    final initialLink = await _appLinks.getInitialLinkString();
    if (initialLink != null) {
      _handleIncomingLink(initialLink);
    }

    // Listen for incoming links
    _appLinks.stringLinkStream.listen((String? link) {
      if (link != null) {
        _handleIncomingLink(link);
      }
    });
  }

  void _handleIncomingLink(String link) {
    // Parse the link and navigate to the appropriate screen
    Uri uri = Uri.parse(link);
    if (uri.host == 'import') {
      String? url = uri.queryParameters['url'];
      if (url != null) {
        Navigator.pushNamed(context, '/socialImport', arguments: url);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Recipe App')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/aiRecipe');
              },
              child: const Text('Generate AI Recipe'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/recipeList');
              },
              child: const Text('My Recipes'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/socialImport');
              },
              child: const Text('Import Recipe from Social Media'),
            ),
          ],
        ),
      ),
    );
  }
}
