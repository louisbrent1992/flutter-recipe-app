import 'package:flutter/material.dart';
import '../theme/theme.dart';

class EditableRecipeField extends StatefulWidget {
  final String label;
  final String value;
  final TextEditingController controller;
  final String hintText;
  final bool isMultiline;
  final Function(String) onSave;
  final Widget? customDisplay;
  final IconData? icon;

  const EditableRecipeField({
    super.key,
    this.label = '',
    required this.controller,
    required this.value,
    required this.hintText,
    required this.onSave,
    this.isMultiline = false,
    this.customDisplay,
    this.icon = Icons.edit_note_rounded,
  });

  @override
  State<EditableRecipeField> createState() => _EditableRecipeFieldState();
}

class _EditableRecipeFieldState extends State<EditableRecipeField> {
  Future<void> _showEditDialog(BuildContext context) async {
    print(widget.controller.value);
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit ${widget.label}'),
          content: TextFormField(
            controller: widget.controller,
            decoration: InputDecoration(hintText: widget.hintText),
            maxLines: widget.isMultiline ? null : 1,

            keyboardType:
                widget.isMultiline
                    ? TextInputType.multiline
                    : TextInputType.text,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                widget.onSave(widget.controller.text);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppElevation.card,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.label,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: Icon(widget.icon),
                      onPressed: () => _showEditDialog(context),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),
            widget.customDisplay ?? Text(widget.controller.text),
          ],
        ),
      ),
    );
  }
}
