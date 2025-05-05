import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipease/components/custom_app_bar.dart';
import 'package:recipease/models/recipe.dart';
import 'package:recipease/providers/recipe_provider.dart';

class ImportRecipeScreen extends StatefulWidget {
  final String? sharedUrl;

  const ImportRecipeScreen({super.key, this.sharedUrl});

  @override
  State<ImportRecipeScreen> createState() => _ImportRecipeScreenState();
}

class _ImportRecipeScreenState extends State<ImportRecipeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();

    // Set the URL from shared intent if available
    if (widget.sharedUrl != null && widget.sharedUrl!.isNotEmpty) {
      _urlController.text = widget.sharedUrl!;

      // Auto import if URL is provided (optional)
      // Uncomment the next line if you want to automatically import the recipe
      // WidgetsBinding.instance.addPostFrameCallback((_) => _importRecipe(context, widget.sharedUrl!));
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _importRecipe(BuildContext context, String url) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid URL'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
      return;
    }

    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);

    try {
      final recipe = await recipeProvider.importRecipeFromUrl(url, context);

      if (context.mounted && recipe != null) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Recipe imported successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        );

        // Navigate to details screen
        _navigateToRecipeDetails(recipe);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        );
      }
    }
  }

  Future<void> _navigateToRecipeDetails(Recipe recipe) async {
    if (mounted) {
      Navigator.pushNamed(context, '/recipeEdit', arguments: recipe);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;

    return SafeArea(
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Import Recipe'),

        body: Consumer<RecipeProvider>(
          builder: (context, recipeProvider, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                // Background decoration with pattern
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.surface,
                          colorScheme.surface.withAlpha(204), // 0.8 alpha
                        ],
                      ),
                    ),
                    child: CustomPaint(
                      painter: _BackgroundPatternPainter(
                        color: colorScheme.primary.withAlpha(8), // 0.03 alpha
                      ),
                    ),
                  ),
                ),

                // Main content
                Positioned.fill(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 14.0,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(height: size.height * 0.08),

                          // Decorative Icon
                          FadeTransition(
                            opacity: _fadeInAnimation,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer.withAlpha(
                                  77,
                                ), // 0.3 alpha
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                Icons.restaurant_rounded,
                                size: 40,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),

                          SizedBox(height: size.height * 0.02),

                          // Title animation
                          FadeTransition(
                            opacity: _fadeInAnimation,
                            child: Text(
                              'Import a Recipe',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Subtitle animation with slight delay
                          AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              return Opacity(
                                opacity: (_animationController.value - 0.3)
                                    .clamp(0.0, 1.0),
                                child: Transform.translate(
                                  offset: Offset(
                                    0,
                                    30 *
                                        (1 -
                                            (_animationController.value - 0.3)
                                                .clamp(0.0, 1.0)),
                                  ),
                                  child: child,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                'Paste a recipe URL below to import recipes from your favorite websites, or click the button below to create a recipe manually',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: colorScheme.onSurface.withAlpha(
                                    179,
                                  ), // 0.7 alpha
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),

                          // URL Input field with animation
                          AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              return Opacity(
                                opacity: (_animationController.value - 0.4)
                                    .clamp(0.0, 1.0),
                                child: Transform.translate(
                                  offset: Offset(
                                    0,
                                    40 *
                                        (1 -
                                            (_animationController.value - 0.4)
                                                .clamp(0.0, 1.0)),
                                  ),
                                  child: child,
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(
                                      20,
                                    ), // 0.08 alpha
                                    blurRadius: 20,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _urlController,
                                decoration: InputDecoration(
                                  hintText: 'https://www.example.com/recipe',
                                  labelText: 'Recipe URL',
                                  hintStyle: TextStyle(
                                    color: colorScheme.onSurface.withAlpha(
                                      102,
                                    ), // 0.4 alpha
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor:
                                      theme.brightness == Brightness.dark
                                          ? colorScheme.surfaceContainerHighest
                                              .withAlpha(
                                                128,
                                              ) // Using surfaceVariant as fallback
                                          : Colors.white,
                                  prefixIcon: Icon(
                                    Icons.link_rounded,
                                    color: colorScheme.primary,
                                  ),
                                  suffixIcon:
                                      _urlController.text.isNotEmpty
                                          ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed:
                                                () => setState(
                                                  () => _urlController.clear(),
                                                ),
                                          )
                                          : null,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                    horizontal: 16,
                                  ),
                                  floatingLabelBehavior:
                                      FloatingLabelBehavior.never,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: colorScheme.outline.withAlpha(
                                        26,
                                      ), // 0.1 alpha
                                      width: 1.0,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: colorScheme.primary.withAlpha(
                                        128,
                                      ), // 0.5 alpha
                                      width: 2.0,
                                    ),
                                  ),
                                ),
                                onSubmitted:
                                    (url) => _importRecipe(context, url),
                                onChanged: (value) => setState(() {}),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 30),

                          // Import button with animation
                          AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              return Opacity(
                                opacity: (_animationController.value - 0.6)
                                    .clamp(0.0, 1.0),
                                child: Transform.translate(
                                  offset: Offset(
                                    0,
                                    30 *
                                        (1 -
                                            (_animationController.value - 0.6)
                                                .clamp(0.0, 1.0)),
                                  ),
                                  child: child,
                                ),
                              );
                            },
                            child: SizedBox(
                              width: 240,
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed:
                                    recipeProvider.isLoading ||
                                            _urlController.text.isEmpty
                                        ? null
                                        : () => _importRecipe(
                                          context,
                                          _urlController.text,
                                        ),
                                icon:
                                    recipeProvider.isLoading
                                        ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                        : const Icon(Icons.download_rounded),
                                label: Text(
                                  recipeProvider.isLoading
                                      ? 'Importing...'
                                      : 'Import Recipe',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: colorScheme.primary,
                                  elevation: 4,
                                  shadowColor: colorScheme.primary.withAlpha(
                                    102,
                                  ), // 0.4 alpha
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 24,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Optional decorative elements
                          SizedBox(height: size.height * 0.12),
                          AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              return Opacity(
                                opacity: (_animationController.value - 0.7)
                                    .clamp(0.0, 1.0),
                                child: child,
                              );
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.help_outline,
                                  size: 16,
                                  color: colorScheme.onSurface.withAlpha(
                                    102,
                                  ), // 0.4 alpha
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Supported sites: AllRecipes, Instagram, Food Network, BBC Food',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: colorScheme.onSurface.withAlpha(
                                        128,
                                      ), // 0.5 alpha
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Floating Action Button
                Positioned(
                  bottom: 24,
                  right: 24,
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale:
                            _animationController.value < 0.8
                                ? 0
                                : (_animationController.value - 0.8) /
                                    0.2 *
                                    1.0,
                        child: child,
                      );
                    },
                    child: FloatingActionButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/recipeEdit');
                      },
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onSecondary,
                      elevation: 4,
                      tooltip: 'Create a recipe manually',
                      child: const Icon(Icons.add_rounded, size: 28),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// Custom painter to draw a subtle pattern in the background
class _BackgroundPatternPainter extends CustomPainter {
  final Color color;

  _BackgroundPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;

    const spacing = 25.0;

    // Draw small circles pattern
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        // Alternate between small circles and dots
        if ((x ~/ spacing + y ~/ spacing) % 3 == 0) {
          canvas.drawCircle(Offset(x, y), 2, paint);
        } else if ((x ~/ spacing + y ~/ spacing) % 3 == 1) {
          canvas.drawCircle(Offset(x, y), 1, paint);
        } else {
          canvas.drawCircle(Offset(x, y), 3, paint..style = PaintingStyle.fill);
          canvas.drawCircle(
            Offset(x, y),
            3,
            paint..style = PaintingStyle.stroke,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_BackgroundPatternPainter oldDelegate) =>
      color != oldDelegate.color;
}
