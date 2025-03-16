import 'package:flutter/material.dart';

class RecipeTags extends StatelessWidget {
  final List<String> tags;
  final Function(String) onAddTag;
  final Function(int) onDeleteTag;

  const RecipeTags({
    super.key,
    required this.tags,
    required this.onAddTag,
    required this.onDeleteTag,
  });

  Future<void> _showAddTagDialog(BuildContext context) async {
    final TextEditingController controller = TextEditingController();

    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add Tag'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'Enter new tag'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    onAddTag(controller.text);
                  }
                  Navigator.pop(context);
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Category Tags:',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showAddTagDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children:
                  List<Widget>.generate(tags.length, (int index) {
                    return Chip(
                      label: Text(tags[index]),
                      onDeleted: () => onDeleteTag(index),
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
