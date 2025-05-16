import 'package:flutter/material.dart';
import 'package:recipease/components/custom_app_bar.dart';
import 'package:recipease/components/editable_recipe_field.dart';
import 'package:recipease/components/recipe_tags.dart';
import 'package:recipease/components/floating_home_button.dart';
import 'package:recipease/models/recipe.dart';
import 'package:recipease/screens/my_recipes_screen.dart';
import 'package:recipease/services/recipe_service.dart';
import 'package:recipease/components/html_description.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';

class RecipeEditScreen extends StatefulWidget {
  const RecipeEditScreen({super.key});

  @override
  State<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends State<RecipeEditScreen> {
  Recipe currentRecipe = Recipe();
  final TextEditingController _imageController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _cuisineTypeController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _ingredientsController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  final TextEditingController _cookingTimeController = TextEditingController();
  final TextEditingController _servingsController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool isInUserRecipes = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();

    // We need to use addPostFrameCallback because we can't access context in initState directly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final arguments = ModalRoute.of(context)?.settings.arguments;
      if (arguments != null && arguments is Recipe) {
        setState(() {
          currentRecipe = arguments;
          // Also update all the controllers with the new values
          _imageController.text = arguments.imageUrl;
          _titleController.text = arguments.title;
          _cuisineTypeController.text = arguments.cuisineType;
          _sourceController.text = arguments.source ?? '';
          _descriptionController.text = arguments.description;
          _ingredientsController.text = arguments.ingredients.join('\n');
          _instructionsController.text = arguments.instructions.join('\n');
          _cookingTimeController.text = arguments.cookingTime;
          _servingsController.text = arguments.servings;
        });

        // Only check if recipe exists in user recipes if we have a recipe ID
        if (arguments.id.isNotEmpty) {
          RecipeService.getUserRecipe(arguments.id).then(
            (response) => setState(() {
              isInUserRecipes = response.success;
            }),
          );
        }
      } else {
        // For new recipe creation, set isInUserRecipes to false
        setState(() {
          isInUserRecipes = false;
        });
      }
    });
  }

  void _updateRecipe({
    String? title,
    String? source,
    String? cuisineType,
    String? description,
    String? imageUrl,
    List<String>? ingredients,
    List<String>? instructions,
    String? cookingTime,
    String? difficulty,
    String? servings,
    List<String>? tags,
  }) {
    setState(() {
      currentRecipe = Recipe(
        id: currentRecipe.id,
        title: title ?? currentRecipe.title,
        cuisineType: cuisineType ?? currentRecipe.cuisineType,
        ingredients: ingredients ?? currentRecipe.ingredients,
        instructions: instructions ?? currentRecipe.instructions,
        description: description ?? currentRecipe.description,
        imageUrl: imageUrl ?? currentRecipe.imageUrl,
        cookingTime: cookingTime ?? currentRecipe.cookingTime,
        difficulty: difficulty ?? currentRecipe.difficulty,
        servings: servings ?? currentRecipe.servings,
        source: source ?? currentRecipe.source,
        tags: tags ?? currentRecipe.tags,
      );
    });
  }

  void _saveRecipe(Recipe currentRecipe) async {
    try {
      final response =
          isInUserRecipes == true
              ? await RecipeService.updateUserRecipe(currentRecipe)
              : await RecipeService.createUserRecipe(currentRecipe);

      print(isInUserRecipes);

      if (response.success && response.data != null) {
        setState(() {
          this.currentRecipe = response.data!;
          isInUserRecipes = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Recipe saved successfully'),
              action: SnackBarAction(
                label: 'Go to My Recipes',
                onPressed: () {
                  Navigator.pushNamed(context, '/myRecipes');
                },
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Failed to save recipe'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save recipe'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadRecipeImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to upload images'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      setState(() => _isUploading = true);

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null) {
        setState(() => _isUploading = false);
        return;
      }

      PlatformFile file = result.files.first;
      final File imageFile = File(file.path!);
      final ext = file.extension ?? 'jpg';

      final storageRef = FirebaseStorage.instance.ref();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${user.uid}_${currentRecipe.id}_$timestamp.$ext';
      final recipeImagesRef = storageRef.child('recipe_images/$fileName');

      final uploadTask = await recipeImagesRef.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/$ext',
          customMetadata: {
            'uploadedBy': user.uid,
            'uploadedAt': timestamp.toString(),
            'recipeId': currentRecipe.id,
          },
        ),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();

      setState(() {
        currentRecipe = currentRecipe.copyWith(imageUrl: downloadUrl);
        _imageController.text = downloadUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _cuisineTypeController.dispose();
    _sourceController.dispose();
    _descriptionController.dispose();
    _ingredientsController.dispose();
    _instructionsController.dispose();
    _cookingTimeController.dispose();
    _servingsController.dispose();
    _tagsController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: currentRecipe.id.isEmpty ? 'Create Recipe' : 'Edit Recipe',
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Scrollbar(
              controller: _scrollController,
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Recipe Header with Image
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: 250,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child:
                                      _isUploading
                                          ? Container(
                                            color: Colors.grey[200],
                                            child: const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          )
                                          : Image.network(
                                            currentRecipe.imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (
                                              context,
                                              error,
                                              stackTrace,
                                            ) {
                                              return Container(
                                                width: double.infinity,
                                                height: 250,
                                                color: Colors.grey[300],
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(
                                                      Icons.broken_image,
                                                      size: 64,
                                                      color: Colors.grey,
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'Failed to load image',
                                                      style: TextStyle(
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                            loadingBuilder: (
                                              context,
                                              child,
                                              loadingProgress,
                                            ) {
                                              if (loadingProgress == null) {
                                                return child;
                                              }
                                              return Container(
                                                width: double.infinity,
                                                height: 250,
                                                color: Colors.grey[200],
                                                child: Center(
                                                  child: CircularProgressIndicator(
                                                    value:
                                                        loadingProgress
                                                                    .expectedTotalBytes !=
                                                                null
                                                            ? loadingProgress
                                                                    .cumulativeBytesLoaded /
                                                                loadingProgress
                                                                    .expectedTotalBytes!
                                                            : null,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                ),
                              ),
                              Positioned(
                                bottom: 10,
                                right: 10,
                                child: Material(
                                  elevation: 4,
                                  shape: const CircleBorder(),
                                  clipBehavior: Clip.hardEdge,
                                  child: InkWell(
                                    onTap:
                                        _isUploading
                                            ? null
                                            : _uploadRecipeImage,
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.secondary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _isUploading
                                            ? Icons.upload
                                            : Icons.camera_alt_rounded,
                                        size: 24,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          EditableRecipeField(
                            label: 'Title',
                            controller: _titleController,
                            value: currentRecipe.title,
                            hintText: 'Enter recipe title',
                            onSave: (value) {
                              setState(() {
                                _updateRecipe(title: _titleController.text);
                                _titleController.text = value;
                              });
                            },
                            customDisplay: Text(
                              currentRecipe.title,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                          const SizedBox(height: 10),
                          EditableRecipeField(
                            label: 'Cuisine Type',
                            controller: _cuisineTypeController,
                            value: currentRecipe.cuisineType,
                            onSave: (value) {
                              setState(() {
                                _updateRecipe(cuisineType: value);
                                _cuisineTypeController.text = value;
                              });
                            },
                            customDisplay: Text(
                              'Fusion',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            hintText: 'Enter recipe cuisine type',
                          ),
                          const SizedBox(height: 10),
                          EditableRecipeField(
                            label: 'Source',
                            controller: _sourceController,
                            value: currentRecipe.source ?? '',
                            hintText: 'Enter recipe source',
                            onSave: (value) {
                              setState(() {
                                _updateRecipe(source: _sourceController.text);
                                _sourceController.text = value;
                              });
                            },
                            customDisplay: Text(
                              currentRecipe.source ??
                                  'Enter recipe source (Instagram, Pinterest, etc.)',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Description
                      EditableRecipeField(
                        label: 'Description',
                        controller: _descriptionController,
                        value: currentRecipe.description,
                        hintText: 'Enter recipe description',
                        isMultiline: true,
                        onSave: (value) {
                          setState(() {
                            _updateRecipe(description: value);
                            _descriptionController.text = value;
                          });
                        },
                        customDisplay: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            HtmlDescription(
                              htmlContent: currentRecipe.description,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Ingredients
                      EditableRecipeField(
                        label: 'Ingredients',
                        controller: _ingredientsController,
                        value: currentRecipe.ingredients.join('\n'),
                        hintText: 'Enter ingredients (separate by comma)',
                        isMultiline: true,

                        onSave: (value) {
                          final ingredients =
                              value
                                  .split('\n')
                                  .map((e) => e.replaceAll(',', '').trim())
                                  .where((e) => e.isNotEmpty)
                                  .toList();
                          setState(() {
                            _updateRecipe(ingredients: ingredients);
                            _ingredientsController.text = value;
                          });
                        },

                        customDisplay: Text(
                          currentRecipe.ingredients.join('\n'),
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Instructions
                      EditableRecipeField(
                        label: 'Instructions',
                        value: currentRecipe.instructions
                            .asMap()
                            .entries
                            .map((entry) => '${entry.key + 1}. ${entry.value}')
                            .join('\n'),
                        controller: _instructionsController,
                        hintText: 'Enter instructions (one per line)',
                        isMultiline: true,
                        onSave: (value) {
                          final instructions =
                              value
                                  .split('\n')
                                  .map(
                                    (e) =>
                                        e
                                            .replaceFirst(
                                              RegExp(r'^\d+\.\s*'),
                                              '',
                                            )
                                            .trim(),
                                  )
                                  .where((e) => e.isNotEmpty)
                                  .toList();
                          setState(() {
                            _updateRecipe(instructions: instructions);
                            _instructionsController.text = value;
                          });
                        },
                        customDisplay: Text(
                          currentRecipe.instructions
                              .asMap()
                              .entries
                              .map(
                                (entry) => '${entry.key + 1}. ${entry.value}',
                              )
                              .join('\n'),
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Cooking Details
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: EditableRecipeField(
                              label: 'Cooking Time',
                              controller: _cookingTimeController,
                              value: currentRecipe.cookingTime,
                              hintText: 'Enter cooking time in minutes',
                              onSave: (value) {
                                setState(() {
                                  _updateRecipe(cookingTime: value);
                                  _cookingTimeController.text = value;
                                });
                              },
                              customDisplay: Text(
                                currentRecipe.cookingTime,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: EditableRecipeField(
                              label: 'Servings',
                              controller: _servingsController,
                              value: currentRecipe.servings,
                              hintText: 'Enter number of servings',
                              onSave: (value) {
                                setState(() {
                                  _updateRecipe(servings: value);
                                  _servingsController.text = value;
                                });
                              },
                              customDisplay: Text(
                                '${currentRecipe.servings} servings',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      // Tags
                      RecipeTags(
                        tags: currentRecipe.tags,
                        onAddTag: (tag) {
                          if (!currentRecipe.tags.contains(tag)) {
                            setState(() {
                              _updateRecipe(tags: [...currentRecipe.tags, tag]);
                            });
                          }
                        },
                        onDeleteTag: (index) {
                          setState(() {
                            final newTags = List<String>.from(
                              currentRecipe.tags,
                            )..removeAt(index);
                            _updateRecipe(tags: newTags);
                          });
                        },
                      ),
                      const SizedBox(height: 15),
                      // Action Buttons
                      Center(
                        child: Wrap(
                          spacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
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
                              onPressed: () => _saveRecipe(currentRecipe),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.tertiary,
                              ),
                              child: Text(
                                isInUserRecipes == true &&
                                        currentRecipe.id.isNotEmpty
                                    ? 'Update'
                                    : 'Save',
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
                            if (currentRecipe.id.isNotEmpty)
                              ElevatedButton(
                                onPressed:
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) =>
                                                const MyRecipesScreen(),
                                      ),
                                    ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                ),
                                child: Text('My Recipes'),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const FloatingHomeButton(),
        ],
      ),
    );
  }
}
