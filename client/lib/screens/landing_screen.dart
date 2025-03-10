import 'package:flutter/material.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              margin: const EdgeInsetsDirectional.fromSTEB(15, 15, 0, 10),

              child: IconButton(
                icon: const Icon(Icons.restaurant_outlined),
                color: Colors.white,
                onPressed: () {
                  Navigator.pushNamed(context, '/home');
                },
                iconSize: 16,
              ),
            ),
          ],
        ),
        titleSpacing: 8,

        title: const Text(
          'Explore',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Center the content
          children: [
            Padding(
              padding: const EdgeInsets.all(
                20.0,
              ), // Add margin around children elements
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      10,
                    ), // Set the desired border radius
                    child: Image.network(
                      'https://images.unsplash.com/photo-1504674900247-0877df9cc836?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=2070&q=80', // Updated URL
                      fit:
                          BoxFit
                              .cover, // Adjust the image to cover the available space
                      width: 300, // Set a specific width for the image
                      height: 300, // Set a specific height for the image
                      errorBuilder: (
                        BuildContext context,
                        Object error,
                        StackTrace? stackTrace,
                      ) {
                        return const Text('Image failed to load');
                      },
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ), // Add spacing between image and text
                  const Text(
                    'Discover delicious recipes!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ), // Style the text for better visibility
                  ),
                  const SizedBox(
                    height: 10,
                  ), // Add spacing between text and button
                  const Text(
                    'Explore a variety of recipes, find new dishes to try, and connect with a community of food enthusiasts!',
                  ),
                  const SizedBox(
                    height: 20,
                  ), // Add spacing between text and button
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/login');
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all<Color>(
                        Theme.of(context).colorScheme.secondary,
                      ), // Use MaterialStateProperty
                      foregroundColor: WidgetStateProperty.all<Color>(
                        Theme.of(context).colorScheme.onPrimary,
                      ), // Use MaterialStateProperty
                      minimumSize: WidgetStateProperty.all<Size>(
                        const Size(double.maxFinite, 50),
                      ), // Use MaterialStateProperty
                      shape: WidgetStateProperty.all<OutlinedBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ), // Use MaterialStateProperty
                      ),
                    ),
                    child: const Text(
                      'Start Cooking',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
