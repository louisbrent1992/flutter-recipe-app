import 'package:flutter/material.dart';
import 'package:recipease/components/app_bar.dart';
import 'package:recipease/components/flavor_card.dart';
import 'package:recipease/components/nav_drawer.dart';
import 'package:recipease/components/trending_recipe_card.dart';
// Removed the import for bottom_nav_bar since it doesn't exist

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Recipease'),
      drawer: const NavDrawer(),
      body: SafeArea(
        child: Scrollbar(
          thumbVisibility: true,
          thickness: 10,
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            // Make the screen scrollable
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Discover new flavors',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),

                      ElevatedButton(
                        onPressed: () {
                          // Navigate to the "See all" screen
                          Navigator.pushNamed(context, '/discoverRecipes');
                        },
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.all<Color>(
                            Theme.of(context).colorScheme.secondary,
                          ),
                          shape:
                              WidgetStateProperty.all<RoundedRectangleBorder>(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                        ),
                        child: Text(
                          'Discover',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,

                    children: [
                      FlavorCard(
                        title: 'Quick Cooking',
                        subtitle: null,
                        imageUrl:
                            'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=900&auto=format&fit=crop&q=60&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxzZWFyY2h8M3x8Zm9vZHxlbnwwfHwwfHx8MA%3D%3D',
                      ),
                      FlavorCard(
                        title: 'Soothing Morning brew',
                        subtitle: null,
                        imageUrl:
                            'https://images.unsplash.com/photo-1482049016688-2d3e1b311543?w=900&auto=format&fit=crop&q=60&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Nnx8Zm9vZHxlbnwwfHwwfHx8MA%3D%3D',
                      ),
                      FlavorCard(
                        title: 'Weekend Kitchen vibes',
                        subtitle: null,
                        imageUrl:
                            'https://plus.unsplash.com/premium_photo-1673108852141-e8c3c22a4a22?w=900&auto=format&fit=crop&q=60&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MXx8Zm9vZHxlbnwwfHwwfHx8MA%3D%3D',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Personalized picks',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // Navigate to the "See all" screen
                        },
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.all<Color>(
                            Theme.of(context).colorScheme.secondary,
                          ),
                          shape:
                              WidgetStateProperty.all<RoundedRectangleBorder>(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                        ),
                        child: Text(
                          'Explore',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      FlavorCard(
                        title: 'Your favorites',
                        subtitle: 'Culinary inspirations',
                        imageUrl:
                            'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=900&auto=format&fit=crop&q=60&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxzZWFyY2h8NHx8Zm9vZHxlbnwwfHwwfHx8MA%3D%3D',
                      ),
                      FlavorCard(
                        title: 'Top picks',
                        subtitle: "Chef's selection",
                        imageUrl:
                            'https://images.unsplash.com/photo-1504674900247-0877df9cc836?q=80&w=870&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Trending recipes',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const TrendingRecipeCard(
                    title: 'Healthy treats',
                    author: 'Samantha',
                  ),
                  const TrendingRecipeCard(
                    title: 'All-time favorites',
                    author: 'Ethan',
                  ),
                  const TrendingRecipeCard(
                    title: 'Cooking together',
                    author: 'Family recipes',
                  ),
                  const TrendingRecipeCard(
                    title: 'Healthy treats',
                    author: 'Samantha',
                  ),
                  const TrendingRecipeCard(
                    title: 'All-time favorites',
                    author: 'Ethan',
                  ),
                  const TrendingRecipeCard(
                    title: 'Cooking together',
                    author: 'Family recipes',
                  ),
                  const TrendingRecipeCard(
                    title: 'Healthy treats',
                    author: 'Samantha',
                  ),
                  const TrendingRecipeCard(
                    title: 'All-time favorites',
                    author: 'Ethan',
                  ),
                  const TrendingRecipeCard(
                    title: 'Cooking together',
                    author: 'Family recipes',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
