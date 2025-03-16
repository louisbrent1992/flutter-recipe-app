import 'package:flutter/material.dart';

class EditableRecipeField extends StatelessWidget {
  final String label;
  final String value;
  final String hintText;
  final bool isMultiline;
  final Function(String) onSave;
  final Widget? customDisplay;
  final IconData? icon;

  const EditableRecipeField({
    super.key,
    required this.label,
    required this.value,
    required this.hintText,
    required this.onSave,
    this.isMultiline = false,
    this.customDisplay,
    this.icon = Icons.edit_note_outlined,
  });

  Future<void> _showEditDialog(BuildContext context) async {
    final TextEditingController controller = TextEditingController(text: value);

    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit $label'),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(hintText: hintText),
              maxLines: isMultiline ? null : 1,
              keyboardType:
                  isMultiline ? TextInputType.multiline : TextInputType.text,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  onSave(controller.text);
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (icon != null)
                  IconButton(
                    icon: Icon(icon),
                    onPressed: () => _showEditDialog(context),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            customDisplay ?? Text(value),
          ],
        ),
      ),
    );
  }
}
