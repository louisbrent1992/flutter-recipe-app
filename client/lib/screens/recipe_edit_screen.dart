import 'package:flutter/material.dart';
import 'package:recipease/components/custom_app_bar.dart';
import 'package:recipease/components/editable_recipe_field.dart';
import 'package:recipease/components/floating_button.dart';
import 'package:recipease/components/recipe_tags.dart';
import 'package:recipease/models/recipe.dart';
import 'package:recipease/components/html_description.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/recipe_provider.dart';
import '../components/error_display.dart';
import '../models/api_response.dart';
import '../theme/theme.dart';
import 'package:recipease/components/floating_bottom_bar.dart';
import '../utils/image_utils.dart';

class RecipeEditScreen extends StatefulWidget {
  final Recipe? recipe;

  const RecipeEditScreen({super.key, this.recipe});

  @override
  State<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends State<RecipeEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _instructionsController;
  late TextEditingController _ingredientsController;
  ApiResponse<Recipe>? _error;
  Recipe currentRecipe = Recipe();
  final TextEditingController _imageController = TextEditingController();
  final TextEditingController _cuisineTypeController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _cookingTimeController = TextEditingController();
  final TextEditingController _servingsController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.recipe?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.recipe?.description ?? '',
    );
    _instructionsController = TextEditingController(
      text: widget.recipe?.instructions.join('\n') ?? '',
    );
    _ingredientsController = TextEditingController(
      text: widget.recipe?.ingredients.join('\n') ?? '',
    );
    _imageController.text = widget.recipe?.imageUrl ?? '';
    _cuisineTypeController.text = widget.recipe?.cuisineType ?? '';
    _sourceController.text = widget.recipe?.source ?? '';
    _cookingTimeController.text = widget.recipe?.cookingTime ?? '';
    _servingsController.text = widget.recipe?.servings ?? '';

    // We need to use addPostFrameCallback because we can't access context in initState directly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final arguments = ModalRoute.of(context)?.settings.arguments;
      if (arguments != null && arguments is Recipe) {
        setState(() {
          currentRecipe = arguments;
          // Also update all the controllers with the new values
          _imageController.text = arguments.imageUrl;
          _cuisineTypeController.text = arguments.cuisineType;
          _sourceController.text = arguments.source ?? '';
          _cookingTimeController.text = arguments.cookingTime;
          _servingsController.text = arguments.servings;
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

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final recipeProvider = Provider.of<RecipeProvider>(
        context,
        listen: false,
      );
      final recipe = Recipe(
        id:
            widget.recipe?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        description: _descriptionController.text,
        instructions:
            _instructionsController.text
                .split('\n')
                .where((i) => i.isNotEmpty)
                .toList(),
        ingredients:
            _ingredientsController.text
                .split('\n')
                .where((i) => i.isNotEmpty)
                .toList(),
        imageUrl: _imageController.text,
        cookingTime: _cookingTimeController.text,
        servings: _servingsController.text,
        cuisineType: _cuisineTypeController.text,
        createdAt: widget.recipe?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        toEdit: widget.recipe?.toEdit ?? false,
        tags: currentRecipe.tags,
      );

      if (widget.recipe?.toEdit == true) {
        final updatedRecipe = await recipeProvider.updateUserRecipe(recipe);
        if (updatedRecipe != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              action: SnackBarAction(
                label: 'View Recipe',
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/recipeDetail',
                    arguments: updatedRecipe,
                  );
                },
              ),
              content: Text(
                'Recipe updated successfully. View it now or continue editing.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final newRecipe = await recipeProvider.createUserRecipe(
          recipe,
          context,
        );
        if (newRecipe != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              action: SnackBarAction(
                label: 'View Recipe',

                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/recipeDetail',
                    arguments: newRecipe,
                  );
                },
              ),
              content: Text(
                'Recipe created successfully. You can view it now.',
                style: TextStyle(color: Colors.white),
              ),
              duration: Duration(seconds: 5),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ApiResponse<Recipe>.error(e.toString());
        });
      }
    } finally {
      if (mounted) {}
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
    _descriptionController.dispose();
    _instructionsController.dispose();
    _ingredientsController.dispose();
    _imageController.dispose();
    _cuisineTypeController.dispose();
    _sourceController.dispose();
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
        title: widget.recipe?.toEdit == true ? 'Edit Recipe' : 'New Recipe',
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Scrollbar(
              controller: _scrollController,
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.responsive(context),
                    AppSpacing.responsive(context),
                    AppSpacing.responsive(context),
                    60,
                  ),
                  child: Consumer<RecipeProvider>(
                    builder: (context, recipeProvider, _) {
                      if (recipeProvider.error != null) {
                        return ErrorDisplay(
                          message: recipeProvider.error!.userFriendlyMessage,
                          isNetworkError: recipeProvider.error!.isNetworkError,
                          isAuthError: recipeProvider.error!.isAuthError,
                          isFormatError: recipeProvider.error!.isFormatError,
                          onRetry: () {
                            recipeProvider.clearError();
                            _saveRecipe();
                          },
                        );
                      }

                      return Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: Text(
                                  _error!.message ?? 'An error occurred',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
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
                                                : ImageUtils.buildRecipeImage(
                                                  imageUrl:
                                                      currentRecipe.imageUrl,
                                                  width: double.infinity,
                                                  height: 250,
                                                  fit: BoxFit.cover,
                                                  errorWidget: Container(
                                                    width: double.infinity,
                                                    height: 250,
                                                    color: Colors.grey[300],
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        const Icon(
                                                          Icons.restaurant,
                                                          size: 64,
                                                          color: Colors.grey,
                                                        ),
                                                        const SizedBox(
                                                          height: 8,
                                                        ),
                                                        Text(
                                                          'Failed to load image',
                                                          style: TextStyle(
                                                            color:
                                                                Colors
                                                                    .grey[600],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 10,
                                      right: 10,
                                      child: Material(
                                        elevation: AppElevation.button,
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
                                                  ).colorScheme.primary,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              _isUploading
                                                  ? Icons.upload
                                                  : Icons.add_a_photo_rounded,
                                              size: 24,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onPrimary,
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
                                      _updateRecipe(
                                        title: _titleController.text,
                                      );
                                      _titleController.text = value;
                                    });
                                  },
                                  customDisplay: Text(
                                    currentRecipe.title,
                                    style:
                                        Theme.of(context).textTheme.bodyLarge,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                EditableRecipeField(
                                  label: 'Source',
                                  controller: _sourceController,
                                  value: currentRecipe.source ?? '',
                                  hintText: 'Enter recipe source',
                                  onSave: (value) {
                                    setState(() {
                                      _updateRecipe(
                                        source: _sourceController.text,
                                      );
                                      _sourceController.text = value;
                                    });
                                  },
                                  customDisplay: Text(
                                    currentRecipe.source ??
                                        'Enter recipe source (Instagram, Pinterest, etc.)',
                                    style:
                                        Theme.of(context).textTheme.bodyLarge,
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
                                    style:
                                        Theme.of(context).textTheme.bodyLarge,
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
                                        .map(
                                          (e) => e.replaceAll(',', '').trim(),
                                        )
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
                                  .map(
                                    (entry) =>
                                        '${entry.key + 1}. ${entry.value}',
                                  )
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
                                      (entry) =>
                                          '${entry.key + 1}. ${entry.value}',
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
                                      style:
                                          Theme.of(context).textTheme.bodyLarge,
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
                                      style:
                                          Theme.of(context).textTheme.bodyLarge,
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
                                    _updateRecipe(
                                      tags: [...currentRecipe.tags, tag],
                                    );
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
                                          Theme.of(
                                            context,
                                          ).colorScheme.secondary,
                                    ),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => _saveRecipe(),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Theme.of(
                                            context,
                                          ).colorScheme.tertiary,
                                    ),
                                    child: Text(
                                      widget.recipe?.toEdit == true
                                          ? 'Update'
                                          : 'Save',
                                      style: TextStyle(
                                        color:
                                            Theme.of(context)
                                                        .colorScheme
                                                        .onTertiary
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
                                          () => Navigator.pushNamed(
                                            context,
                                            '/myRecipes',
                                          ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                      ),
                                      child: Text('My Recipes'),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          FloatingBottomBar(),
          FloatingButton(
            onPressed: () => _saveRecipe(),
            tooltip: 'Save Recipe',
            icon: Icons.save,
          ),
        ],
      ),
    );
  }
}
