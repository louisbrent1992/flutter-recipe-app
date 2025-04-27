import 'package:flutter/material.dart';

class DietaryPreferenceCheckboxList extends StatefulWidget {
  final String label;
  final List<String> selectedPreferences;
  final Function(List<String>)? onChanged;

  const DietaryPreferenceCheckboxList({
    super.key,
    required this.label,
    required this.selectedPreferences,
    required this.onChanged,
  });

  @override
  State<DietaryPreferenceCheckboxList> createState() =>
      DietaryPreferenceCheckboxListState();
}

class DietaryPreferenceCheckboxListState
    extends State<DietaryPreferenceCheckboxList> {
  final List<String> _selectedPreferences = [];

  @override
  void initState() {
    super.initState();
    _selectedPreferences.addAll(widget.selectedPreferences);
  }

  void _handlePreferenceChange(String preference, bool value) {
    setState(() {
      if (value) {
        if (!_selectedPreferences.contains(preference)) {
          _selectedPreferences.add(preference);
        }
      } else {
        _selectedPreferences.remove(preference);
      }
      widget.onChanged?.call(_selectedPreferences);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Keto'),
            Checkbox(
              value: _selectedPreferences.contains('keto'),
              onChanged: (bool? value) {
                _handlePreferenceChange('keto', value ?? false);
              },
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Gluten Free'),
            Checkbox(
              value: _selectedPreferences.contains('gluten-free'),
              onChanged: (bool? value) {
                _handlePreferenceChange('gluten-free', value ?? false);
              },
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Vegan'),
            Checkbox(
              value: _selectedPreferences.contains('vegan'),
              onChanged: (bool? value) {
                _handlePreferenceChange('vegan', value ?? false);
              },
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Vegetarian'),
            Checkbox(
              value: _selectedPreferences.contains('vegetarian'),
              onChanged: (bool? value) {
                _handlePreferenceChange('vegetarian', value ?? false);
              },
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Spicy'),
            Checkbox(
              value: _selectedPreferences.contains('spicy'),
              onChanged: (bool? value) {
                _handlePreferenceChange('spicy', value ?? false);
              },
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Healthy'),
            Checkbox(
              value: _selectedPreferences.contains('healthy'),
              onChanged: (bool? value) {
                _handlePreferenceChange('healthy', value ?? false);
              },
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Organic'),
            Checkbox(
              value: _selectedPreferences.contains('organic'),
              onChanged: (bool? value) {
                _handlePreferenceChange('organic', value ?? false);
              },
            ),
          ],
        ),
      ],
    );
  }
}
