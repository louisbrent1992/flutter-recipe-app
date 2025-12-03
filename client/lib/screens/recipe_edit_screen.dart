import 'package:flutter/material.dart';
import 'package:recipease/components/custom_app_bar.dart';
import 'package:recipease/components/editable_recipe_field.dart';

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
import '../utils/image_utils.dart';
import '../services/google_image_service.dart';

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

  Future<void> _regenerateImage() async {
    if (currentRecipe.id.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Save the recipe first to regenerate image.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }
    try {
      setState(() => _isUploading = true);
      final query =
          (_titleController.text.isNotEmpty
                  ? _titleController.text
                  : currentRecipe.title)
              .trim();
      final next = await GoogleImageService.fetchImageForQuery(
        '$query recipe',
        start: 4,
      );
      if (next == null || next.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Unable to find a new image right now.'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }
      setState(() {
        currentRecipe = currentRecipe.copyWith(imageUrl: next);
        _imageController.text = next;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Image updated.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error while regenerating image.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // Prime currentRecipe from constructor (preferred path when editing)
    if (widget.recipe != null) {
      currentRecipe = widget.recipe!.copyWith(toEdit: true);
    }

    _titleController = TextEditingController(text: currentRecipe.title);
    _descriptionController = TextEditingController(
      text: currentRecipe.description,
    );
    _instructionsController = TextEditingController(
      text: currentRecipe.instructions.join('\n'),
    );
    _ingredientsController = TextEditingController(
      text: currentRecipe.ingredients.join('\n'),
    );
    _imageController.text = currentRecipe.imageUrl;
    _cuisineTypeController.text = currentRecipe.cuisineType;
    _sourceController.text = currentRecipe.source ?? '';
    _cookingTimeController.text = currentRecipe.cookingTime;
    _servingsController.text = currentRecipe.servings;

    // We need to use addPostFrameCallback because we can't access context in initState directly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final arguments = ModalRoute.of(context)?.settings.arguments;
      if (arguments != null && arguments is Recipe) {
        setState(() {
          currentRecipe = arguments.copyWith(toEdit: true);
          // Also update all the controllers with the new values
          _imageController.text = arguments.imageUrl;
          _cuisineTypeController.text = arguments.cuisineType;
          _sourceController.text = arguments.source ?? '';
          _cookingTimeController.text = arguments.cookingTime;
          _servingsController.text = arguments.servings;
          _titleController.text = arguments.title;
          _descriptionController.text = arguments.description;
          _instructionsController.text = arguments.instructions.join('\n');
          _ingredientsController.text = arguments.ingredients.join('\n');
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
    // Safely check if form is valid
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }

    try {
      final recipeProvider = Provider.of<RecipeProvider>(
        context,
        listen: false,
      );
      final recipe = Recipe(
        id:
            currentRecipe.id.isNotEmpty
                ? currentRecipe.id
                : (widget.recipe?.id ??
                    DateTime.now().millisecondsSinceEpoch.toString()),
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
        // Preserve import metadata so source link renders on details screen
        difficulty: currentRecipe.difficulty,
        source:
            (_sourceController.text.isNotEmpty
                ? _sourceController.text
                : currentRecipe.source),
        sourceUrl: currentRecipe.sourceUrl,
        sourcePlatform: currentRecipe.sourcePlatform,
        author: currentRecipe.author,
        instagram: currentRecipe.instagram,
        tiktok: currentRecipe.tiktok,
        youtube: currentRecipe.youtube,
        aiGenerated: currentRecipe.aiGenerated,
        createdAt: currentRecipe.createdAt,
        updatedAt: DateTime.now(),
        toEdit: true,
        tags: currentRecipe.tags,
      );

      // Check if we're updating an existing user recipe:
      // Only update if the original widget.recipe had toEdit=true (means it came from user's collection)
      // If widget.recipe is null or toEdit is false/null, it's a new recipe (imported or created)
      final bool isUpdatingExisting = widget.recipe?.toEdit == true;

      if (isUpdatingExisting) {
        final updatedRecipe = await recipeProvider.updateUserRecipe(recipe);
        if (updatedRecipe != null && mounted) {
          // Clear any previous errors on successful update
          setState(() {
            _error = null;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              action: SnackBarAction(
                label: 'View Recipe',
                onPressed: () {
                  if (mounted) {
                    Navigator.pushNamed(
                      context,
                      '/recipeDetail',
                      arguments: updatedRecipe,
                    );
                  }
                },
              ),
              content: Text(
                'Recipe updated successfully. View it now or continue editing.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.surface.withValues(
                    alpha: Theme.of(context).colorScheme.alphaVeryHigh,
                  ),
                ),
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else if (mounted) {
          // Recipe update failed
          setState(() {
            _error = ApiResponse<Recipe>.error('Failed to update recipe');
          });
        }
      } else {
        final newRecipe = await recipeProvider.createUserRecipe(
          recipe,
          context,
        );
        if (newRecipe != null && mounted) {
          // Clear any previous errors on successful save
          setState(() {
            _error = null;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              action: SnackBarAction(
                label: 'View Recipes',
                onPressed: () {
                  if (mounted) {
                    Navigator.pushNamed(
                      context,
                      '/myRecipes',
                      arguments: newRecipe,
                    );
                  }
                },
              ),
              content: Text(
                'Recipe saved successfully.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.surface.withValues(
                    alpha: Theme.of(context).colorScheme.alphaVeryHigh,
                  ),
                ),
              ),
              duration: Duration(seconds: 8),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
          );

          // After saving a new recipe, return to the Import screen to add a new one
          Navigator.pushReplacementNamed(context, '/import');
        } else if (mounted) {
          // Recipe save failed
          setState(() {
            _error = ApiResponse<Recipe>.error('Failed to save recipe');
          });
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
        title:
            (widget.recipe?.toEdit == true || currentRecipe.toEdit == true)
                ? 'Edit'
                : 'New',
        fullTitle:
            (widget.recipe?.toEdit == true || currentRecipe.toEdit == true)
                ? 'Edit Recipe'
                : 'New Recipe',
        floatingButtons: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save Recipe',
            onPressed: () => _saveRecipe(),
          ),
        ],
      ),
      body: Stack(
        children: [
          Scrollbar(
              controller: _scrollController,
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: AppBreakpoints.isDesktop(context)
                          ? 800
                          : AppBreakpoints.isTablet(context)
                              ? 700
                              : double.infinity,
                    ),
                  padding: EdgeInsets.only(
                    left: AppSpacing.responsive(context),
                    right: AppSpacing.responsive(context),
                    top: AppSpacing.responsive(context),
                    bottom: AppSpacing.responsive(context) + 30, // Extra space for floating bar
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
                                      height: AppBreakpoints.isDesktop(context)
                                          ? 350
                                          : AppBreakpoints.isTablet(context)
                                              ? 300
                                              : 250,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          AppBreakpoints.isDesktop(context)
                                              ? 16
                                              : AppBreakpoints.isTablet(context)
                                                  ? 14
                                                  : 12,
                                        ),
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
                                                  height: AppBreakpoints
                                                          .isDesktop(context)
                                                      ? 350
                                                      : AppBreakpoints.isTablet(
                                                              context,
                                                            )
                                                          ? 300
                                                          : 250,
                                                  fit: BoxFit.cover,
                                                  errorWidget: Container(
                                                    width: double.infinity,
                                                    height: AppBreakpoints
                                                            .isDesktop(context)
                                                        ? 350
                                                        : AppBreakpoints
                                                                .isTablet(
                                                              context,
                                                            )
                                                            ? 300
                                                            : 250,
                                                    color: Colors.grey[300],
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(
                                                          Icons.restaurant,
                                                          size: AppSizing
                                                              .responsiveIconSize(
                                                            context,
                                                            mobile: 64,
                                                            tablet: 80,
                                                            desktop: 96,
                                                          ),
                                                          color: Colors.grey,
                                                        ),
                                                        SizedBox(
                                                          height: AppBreakpoints
                                                                  .isDesktop(
                                                                context,
                                                              )
                                                              ? 12
                                                              : AppBreakpoints
                                                                      .isTablet(
                                                                    context,
                                                                  )
                                                                  ? 10
                                                                  : 8,
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
                                      child: Row(
                                        children: [
                                          // Regenerate (only for saved recipes)
                                          Material(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest
                                                .withValues(alpha: 0.9),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              side: BorderSide(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withValues(alpha: 0.3),
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          InkWell(
                                            onTap:
                                                (_isUploading ||
                                                        currentRecipe
                                                            .id
                                                            .isEmpty)
                                                    ? null
                                                    : _regenerateImage,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHighest
                                                    .withValues(alpha: 0.9),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withValues(alpha: 0.3),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Icon(
                                                Icons.image_search,
                                                size: 20,
                                                color:
                                                    (_isUploading ||
                                                            currentRecipe
                                                                .id
                                                                .isEmpty)
                                                        ? Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant
                                                            .withValues(
                                                              alpha: 0.5,
                                                            )
                                                        : Theme.of(
                                                          context,
                                                        ).colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Add photo (upload)
                                          InkWell(
                                            onTap:
                                                _isUploading
                                                    ? null
                                                    : _uploadRecipeImage,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHighest
                                                    .withValues(alpha: 0.9),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withValues(alpha: 0.3),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Icon(
                                                _isUploading
                                                    ? Icons.upload
                                                    : Icons.add_a_photo_rounded,
                                                size: 20,
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                        ],
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
                            // Bottom buttons removed; Save is available in the app bar
                            const SizedBox(height: 8),
                          ],
                        ),
                      );
                    },
                  ),
                  ),
                ),
              ),
          ),
        ],
        ),
      );
  }
}
