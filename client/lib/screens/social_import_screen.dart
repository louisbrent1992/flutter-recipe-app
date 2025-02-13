import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';

class SocialImportScreen extends StatefulWidget {
  const SocialImportScreen({super.key});

  @override
  _SocialImportScreenState createState() => _SocialImportScreenState();
}

class _SocialImportScreenState extends State<SocialImportScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _urlController = TextEditingController();
  Recipe? _importedRecipe;
  bool _isLoading = false;

  void _importRecipe() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      Recipe recipe = await ApiService.importSocialRecipe(_urlController.text);
      setState(() {
        _importedRecipe = recipe;
        _isLoading = false;
      });
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
      appBar: AppBar(title: Text('Import Recipe from Social Media')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  child: Column(
                    children: [
                      Form(
                        key: _formKey,
                        child: TextFormField(
                          controller: _urlController,
                          decoration: InputDecoration(
                            labelText: 'Enter Social Media URL',
                          ),
                          validator:
                              (value) =>
                                  value == null || value.isEmpty
                                      ? 'Enter URL'
                                      : null,
                        ),
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _importRecipe,
                        child: Text('Import Recipe'),
                      ),
                      if (_importedRecipe != null) ...[
                        SizedBox(height: 20),
                        Text(
                          _importedRecipe!.title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Ingredients: ${_importedRecipe!.ingredients.join(", ")}',
                        ),
                        SizedBox(height: 10),
                        Text('Steps: ${_importedRecipe!.steps.join(" -> ")}'),
                      ],
                    ],
                  ),
                ),
      ),
    );
  }
}
