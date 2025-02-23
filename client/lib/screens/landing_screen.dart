import 'package:flutter/material.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 60,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Icon(Icons.restaurant_outlined, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(
              width: 8,
            ), // Add some spacing between the icon and the title
            const Text('Explore'),
          ],
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
                  Image.network(
                    'https://res.cloudinary.com/client-images/image/upload/v1695070874/eCommerce%20Site%20Images/about-image_sasb2y.png', // Updated URL
                    fit:
                        BoxFit
                            .cover, // Adjust the image to cover the available space
                    width: 400, // Set a specific width for the image
                    height: 400, // Set a specific height for the image
                    errorBuilder: (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) {
                      return const Text('Image failed to load');
                    },
                  ),
                  const SizedBox(height: 20), // Add spacing between image and text
                  const Text(
                    'Discover delicious recipes!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ), // Style the text for better visibility
                  ),
                  const SizedBox(height: 10), // Add spacing between text and button
                  const Text(
                    'Explore a variety of recipes, find new dishes to try, and connect with a community of food enthusiasts!',
                  ),
                  const SizedBox(height: 20), // Add spacing between text and button
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/home');
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all<Color>(
                        Colors.black,
                      ), // Use MaterialStateProperty
                      foregroundColor: WidgetStateProperty.all<Color>(
                        Colors.white,
                      ), // Use MaterialStateProperty
                      minimumSize: WidgetStateProperty.all<Size>(
                        const Size(double.maxFinite, 50),
                      ), // Use MaterialStateProperty
                    ),
                    child: const Text('Start Cooking'),
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
