import 'package:flutter/material.dart';

class TrendingRecipeCard extends StatelessWidget {
  final String title;
  final String author;
  final String? imageUrl;

  const TrendingRecipeCard({
    Key? key,
    required this.title,
    required this.author,
    this.imageUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
              image: DecorationImage(
                image: NetworkImage(
                  imageUrl ??
                      'https://images.unsplash.com/photo-1511690656952-34342bb7c2f2?w=900&auto=format&fit=crop&q=60&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxzZWFyY2h8OHx8Zm9vZHxlbnwwfHwwfHx8MA%3D%3D',
                ),
                fit: BoxFit.cover,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(15)),

              // Updated link for profile pic
            ),
            width: 50,
            height: 50,
          ),
          const SizedBox(width: 10), // Add spacing between image and text
          Expanded(
            child: ListTile(
              title: Text(title),
              subtitle: Text(author),
              trailing: const Icon(Icons.restaurant_menu_outlined),
              onTap: () {
                // Navigate to the respective recipe details
                Navigator.pushNamed(context, '/recipeDetail');
              },
            ),
          ),
        ],
      ),
    );
  }
}
