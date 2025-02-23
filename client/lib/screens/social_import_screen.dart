import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';

class SocialImportScreen extends StatefulWidget {
  final String? url;

  const SocialImportScreen({super.key, this.url});

  @override
  SocialImportScreenState createState() => SocialImportScreenState();
}

class SocialImportScreenState extends State<SocialImportScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _urlController = TextEditingController();
  Recipe? _importedRecipe;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.url != null) {
      _urlController.text = widget.url!;
      _importRecipe();
    }
  }

  void _importRecipe() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        Recipe recipe = await ApiService.importSocialRecipe(
          _urlController.text,
        );
        if (mounted) {
          setState(() {
            _importedRecipe = recipe;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to import recipe: $e')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Recipe from Social Media')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'Enter Social Media URL',
                  ),
                  validator:
                      (value) =>
                          value == null || value.isEmpty ? 'Enter URL' : null,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _importRecipe,
                  child: const Text('Import Recipe'),
                ),
                if (_isLoading) ...[
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(),
                ],
                if (_importedRecipe != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    _importedRecipe!.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Ingredients: ${_importedRecipe!.ingredients.join(", ")}',
                  ),
                  const SizedBox(height: 10),
                  Text('Steps: ${_importedRecipe!.steps.join(" -> ")}'),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
