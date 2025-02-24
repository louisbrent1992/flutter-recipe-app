import 'package:flutter/material.dart';
import 'package:recipease/components/bottom_nav_bar.dart';
// Removed the import for bottom_nav_bar since it doesn't exist

class NewHomeScreen extends StatelessWidget {
  const NewHomeScreen({Key? key})
    : super(key: key); // Updated constructor for clarity

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Good afternoon, chef!',
          style: TextStyle(fontSize: 20),
        ),
        titleSpacing: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Handle search action
              Navigator.pushNamed(context, '/search');
            },
            padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 0, 10),
            iconSize: 30,
          ),

          Container(
            margin: const EdgeInsetsDirectional.fromSTEB(10, 10, 10, 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 1),
            ),

            child: Image.network(
              'https://img.icons8.com/?size=100&id=nSR7D8Yb2tjC&format=png&color=000000',
              fit: BoxFit.cover,
              height: 30,

              // Updated link for profile pic
            ),
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          // Make the screen scrollable
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Discover new flavors',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w400),
                  ),

                  ElevatedButton(
                    onPressed: () {
                      // Navigate to the "See all" screen
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all<Color>(
                        Colors.black,
                      ),
                      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                    child: const Text(
                      'Explore',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,

                children: [
                  _buildFlavorCard('Quick Cooking'),
                  _buildFlavorCard('Soothing Morning brew'),
                  _buildFlavorCard('Weekend Kitchen vibes'),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Personalized picks',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w400),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to the "See all" screen
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all<Color>(
                        Colors.black,
                      ),
                      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                    child: const Text(
                      'Discover',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildFlavorCard('Your favorites', 'Culinary inspirations'),
                  _buildFlavorCard('Top picks', "Chef's selection"),
                ],
              ),
              const SizedBox(height: 15),
              const Text(
                'Trending recipes',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              _buildTrendingRecipe('Healthy treats', 'Samantha'),
              _buildTrendingRecipe('All-time favorites', 'Ethan'),
              _buildTrendingRecipe('Cooking together', 'Family recipes'),
              _buildTrendingRecipe('Healthy treats', 'Samantha'),
              _buildTrendingRecipe('All-time favorites', 'Ethan'),
              _buildTrendingRecipe('Cooking together', 'Family recipes'),
              _buildTrendingRecipe('Healthy treats', 'Samantha'),
              _buildTrendingRecipe('All-time favorites', 'Ethan'),
              _buildTrendingRecipe('Cooking together', 'Family recipes'),
            ],
          ),
        ),
      ),
      extendBody: true,
      bottomNavigationBar: const TransparentBtmNavBarCurvedFb1(),
    );
  }

  Widget _buildFlavorCard(String title, [String? subtitle]) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            height: 100,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                if (subtitle != null) Text(subtitle),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrendingRecipe(String title, String author, [String? imageUrl]) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              border: Border.all(color: Colors.black, width: 1),
              borderRadius: const BorderRadius.all(Radius.circular(15)),

              // Updated link for profile pic
            ),
            width: 50,
            height: 50,

            child: Image.network(
              imageUrl ??
                  'https://img.icons8.com/?size=100&id=nSR7D8Yb2tjC&format=png&color=000000',
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10), // Add spacing between image and text
          Expanded(
            child: ListTile(
              title: Text(title),
              subtitle: Text(author),
              trailing: const Icon(Icons.restaurant_menu_outlined),
              onTap: () {
                // Navigate to recipe detail or perform an action
              },
            ),
          ),
        ],
      ),
    );
  }
}
