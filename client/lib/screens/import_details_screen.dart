import 'package:flutter/material.dart';
import 'package:recipease/components/app_bar.dart';
import 'package:recipease/components/nav_drawer.dart';

class ImportDetailsScreen extends StatefulWidget {
  const ImportDetailsScreen({super.key});

  @override
  State<ImportDetailsScreen> createState() => _ImportDetailsScreenState();
}

class _ImportDetailsScreenState extends State<ImportDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Import Recipe'),
      drawer: const NavDrawer(),
      body: SafeArea(
        child: Scrollbar(
          thumbVisibility: true,
          thickness: 10,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 250,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                10,
                              ), // Rounded corners
                              child: Image.network('', fit: BoxFit.cover),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const Icon(Icons.edit_note_outlined),
                            ],
                          ),
                          const Text('Shared from '),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Additional input fields
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Description:',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Icon(Icons.edit_note_outlined),
                            ],
                          ),
                          SizedBox(height: 10),
                          Text(''),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Ingredients:',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Icon(Icons.edit_note_outlined),
                              ],
                            ),
                            SizedBox(height: 10),
                            Text(''),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Instructions:',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Icon(Icons.edit_note_outlined),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Shared files:",
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                'Cooking Time:  minutes',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                          ),
                          SizedBox(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  'Servings: ',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Category Tags:',
                                    style:
                                        Theme.of(context).textTheme.labelLarge,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_note_outlined),
                                    onPressed: () {
                                      // Add your edit functionality here
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 15),
                              // Wrap(
                              //   spacing: 8.0, // gap between adjacent chips
                              //   runSpacing: 4.0, // gap between lines
                              //   children:
                              //       List<Widget>.generate(recipe.tags.length, (
                              //         int index,
                              //       ) {
                              //         return Chip(
                              //           label: Text(recipe.tags[index]),
                              //           onDeleted: () {
                              //             setState(() {
                              //               recipe.tags.removeAt(index);
                              //             });
                              //           },
                              //         );
                              //       }).toList(),
                              // ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          // Handle import action
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.secondary,
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // Handle import action
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                        ),
                        child: const Row(
                          spacing: 5,
                          children: [
                            Icon(Icons.auto_awesome, color: Colors.white),
                            Text(
                              'Autofill',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // Handle another action (e.g., Save)
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.tertiary,
                        ),
                        child: Text(
                          'Save',
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onTertiary
                                            .computeLuminance() >
                                        0.5
                                    ? Colors.black
                                    : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
