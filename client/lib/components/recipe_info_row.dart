import 'package:flutter/material.dart';

class RecipeInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final EdgeInsets? padding;

  const RecipeInfoRow({
    super.key,
    required this.icon,
    required this.text,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 4),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
