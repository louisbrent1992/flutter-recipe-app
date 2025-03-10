import 'package:flutter/material.dart';

class DietaryPreferenceCheckboxList extends StatefulWidget {
  final String label;
  final bool value;
  final Function(bool?)? onChanged;

  const DietaryPreferenceCheckboxList({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  @override
  State<DietaryPreferenceCheckboxList> createState() =>
      DietaryPreferenceCheckboxListState();
}

class DietaryPreferenceCheckboxListState
    extends State<DietaryPreferenceCheckboxList> {
  bool _vegan = false;

  bool _keto = false;

  bool _glutenFree = false;

  bool _vegetarian = false;

  bool _spicy = false;

  bool _healthy = false;

  bool _organic = false;

  final TextEditingController _otherController = TextEditingController();

  var children = <Widget>[];

  void update(bool? value) {
    setState(() {
      _vegan = value!;
      _keto = value;
      _glutenFree = value;
      _vegetarian = value;
      _spicy = value;
      _healthy = value;
      _organic = value;
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
              value: _keto,
              onChanged: (bool? value) {
                setState(() {
                  _keto = value!;
                });
              },
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Gluten Free'),
            Checkbox(
              value: _glutenFree,
              onChanged: (bool? value) {
                setState(() {
                  _glutenFree = value!;
                });
              },
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Vegan'),
            Checkbox(
              value: _vegan,
              onChanged: (bool? value) {
                setState(() {
                  _vegan = value!;
                });
              },
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Vegetarian'),
            Checkbox(
              value: _vegetarian,
              onChanged: (bool? value) {
                setState(() {
                  _vegetarian = value!;
                });
              },
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Spicy'),
            Checkbox(
              value: _spicy,
              onChanged: (bool? value) {
                setState(() {
                  _spicy = value!;
                });
              },
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Healthy'),
            Checkbox(
              value: _healthy,
              onChanged: (bool? value) {
                setState(() {
                  _healthy = value!;
                });
              },
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Organic'),
            Checkbox(
              value: _organic,
              onChanged: (bool? value) {
                setState(() {
                  _organic = value!;
                });
              },
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _otherController,
                decoration: const InputDecoration(
                  hintText: 'Other (e.g. no peanuts, dairy-free, etc.)',
                ),
                onChanged: (text) {
                  setState(() {
                    // Handle the input text if needed
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
