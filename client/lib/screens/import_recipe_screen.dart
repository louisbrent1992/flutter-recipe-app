import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipease/components/custom_app_bar.dart';
import 'package:recipease/components/floating_bottom_bar.dart';
import 'package:recipease/components/floating_button.dart';
import 'package:recipease/models/recipe.dart';
import 'package:recipease/providers/recipe_provider.dart';
import 'package:recipease/theme/theme.dart';

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

    return Scaffold(
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
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          MediaQuery.of(context).size.height -
                          MediaQuery.of(context).padding.top -
                          kToolbarHeight -
                          MediaQuery.of(context).padding.bottom,
                      maxWidth: AppSizing.responsiveMaxWidth(context),
                    ),
                    child: Padding(
                      padding: AppSpacing.allResponsive(context),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Main content section
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(height: size.height * 0.08),

                              // Decorative Icon
                              FadeTransition(
                                opacity: _fadeInAnimation,
                                child: Container(
                                  width: AppSizing.responsiveIconSize(
                                    context,
                                    mobile: 70,
                                    tablet: 80,
                                    desktop: 90,
                                  ),
                                  height: AppSizing.responsiveIconSize(
                                    context,
                                    mobile: 70,
                                    tablet: 80,
                                    desktop: 90,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withAlpha(
                                      77,
                                    ), // 0.3 alpha
                                    borderRadius: BorderRadius.circular(
                                      AppBreakpoints.isMobile(context)
                                          ? 16
                                          : 20,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.ios_share_rounded,
                                    size: AppSizing.responsiveIconSize(
                                      context,
                                      mobile: 35,
                                      tablet: 40,
                                      desktop: 45,
                                    ),
                                    color: Colors.green,
                                  ),
                                ),
                              ),

                              SizedBox(height: AppSpacing.lg),

                              // Title animation
                              FadeTransition(
                                opacity: _fadeInAnimation,
                                child: Text(
                                  'Import a Recipe',
                                  style: TextStyle(
                                    fontSize:
                                        AppTypography.responsiveHeadingSize(
                                          context,
                                          mobile: 26.0,
                                          tablet: 32.0,
                                          desktop: 36.0,
                                        ),
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),

                              SizedBox(height: AppSpacing.md),

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
                                                (_animationController.value -
                                                        0.3)
                                                    .clamp(0.0, 1.0)),
                                      ),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: AppSpacing.horizontalResponsive(
                                    context,
                                  ),
                                  child: RichText(
                                    textAlign: TextAlign.center,
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontSize:
                                            AppTypography.responsiveFontSize(
                                              context,
                                            ),
                                        color: colorScheme.onSurface.withAlpha(
                                          179,
                                        ), // 0.7 alpha
                                      ),
                                      children: [
                                        const TextSpan(text: 'Tap the '),
                                        WidgetSpan(
                                          child: Icon(
                                            Icons.share,
                                            size: AppSizing.responsiveIconSize(
                                              context,
                                              mobile: 16,
                                              tablet: 18,
                                              desktop: 20,
                                            ),
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                        const TextSpan(
                                          text:
                                              ' share button in your favorite social media app, or paste a recipe URL below to import recipes. You can also create a recipe manually using the ',
                                        ),
                                        WidgetSpan(
                                          child: Icon(
                                            Icons.add_circle,
                                            size: AppSizing.responsiveIconSize(
                                              context,
                                              mobile: 16,
                                              tablet: 18,
                                              desktop: 20,
                                            ),
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                        const TextSpan(
                                          text:
                                              ' button at the bottom of your screen.',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(height: AppSpacing.xxl),

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
                                                (_animationController.value -
                                                        0.4)
                                                    .clamp(0.0, 1.0)),
                                      ),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      AppBreakpoints.isMobile(context)
                                          ? 12
                                          : 16,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(
                                          20,
                                        ), // 0.08 alpha
                                        blurRadius:
                                            AppBreakpoints.isMobile(context)
                                                ? 15
                                                : 20,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: TextField(
                                    controller: _urlController,
                                    decoration: InputDecoration(
                                      hintText:
                                          'https://www.example.com/recipe',
                                      labelText: 'Paste recipe URL here',
                                      hintStyle: TextStyle(
                                        color: colorScheme.onSurface.withAlpha(
                                          102,
                                        ), // 0.4 alpha
                                        fontSize:
                                            AppTypography.responsiveFontSize(
                                              context,
                                            ),
                                      ),
                                      labelStyle: TextStyle(
                                        fontSize:
                                            AppTypography.responsiveFontSize(
                                              context,
                                            ),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppBreakpoints.isMobile(context)
                                              ? 12
                                              : 16,
                                        ),
                                        borderSide: BorderSide.none,
                                      ),
                                      filled: true,
                                      fillColor:
                                          theme.brightness == Brightness.dark
                                              ? colorScheme
                                                  .surfaceContainerHighest
                                                  .withAlpha(
                                                    128,
                                                  ) // Using surfaceContainerHighest as fallback
                                              : Colors.white,
                                      prefixIcon: Icon(
                                        Icons.link_rounded,
                                        color: colorScheme.primary,
                                        size: AppSizing.responsiveIconSize(
                                          context,
                                          mobile: 20,
                                          tablet: 22,
                                          desktop: 24,
                                        ),
                                      ),
                                      suffixIcon:
                                          _urlController.text.isNotEmpty
                                              ? IconButton(
                                                icon: Icon(
                                                  Icons.clear,
                                                  size:
                                                      AppSizing.responsiveIconSize(
                                                        context,
                                                        mobile: 20,
                                                        tablet: 22,
                                                        desktop: 24,
                                                      ),
                                                ),
                                                onPressed:
                                                    () => setState(
                                                      () =>
                                                          _urlController
                                                              .clear(),
                                                    ),
                                              )
                                              : null,
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: AppSpacing.lg,
                                        horizontal: AppSpacing.md,
                                      ),
                                      floatingLabelBehavior:
                                          FloatingLabelBehavior.never,
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppBreakpoints.isMobile(context)
                                              ? 12
                                              : 16,
                                        ),
                                        borderSide: BorderSide(
                                          color: colorScheme.outline.withAlpha(
                                            26,
                                          ), // 0.1 alpha
                                          width: 1.0,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppBreakpoints.isMobile(context)
                                              ? 12
                                              : 16,
                                        ),
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
                                      fontSize:
                                          AppTypography.responsiveFontSize(
                                            context,
                                          ),
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(height: AppSpacing.md),

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
                                                (_animationController.value -
                                                        0.6)
                                                    .clamp(0.0, 1.0)),
                                      ),
                                      child: child,
                                    ),
                                  );
                                },
                                child: SizedBox(
                                  width:
                                      AppBreakpoints.isMobile(context)
                                          ? 200
                                          : 240,
                                  height:
                                      AppBreakpoints.isMobile(context)
                                          ? 50
                                          : 56,
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
                                            ? SizedBox(
                                              width:
                                                  AppSizing.responsiveIconSize(
                                                    context,
                                                    mobile: 18,
                                                    tablet: 20,
                                                    desktop: 22,
                                                  ),
                                              height:
                                                  AppSizing.responsiveIconSize(
                                                    context,
                                                    mobile: 18,
                                                    tablet: 20,
                                                    desktop: 22,
                                                  ),
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    const AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                            )
                                            : Icon(
                                              Icons.download_rounded,
                                              size:
                                                  AppSizing.responsiveIconSize(
                                                    context,
                                                    mobile: 20,
                                                    tablet: 22,
                                                    desktop: 24,
                                                  ),
                                            ),
                                    label: Text(
                                      recipeProvider.isLoading
                                          ? 'Importing...'
                                          : 'Import Recipe',
                                      style: TextStyle(
                                        fontSize:
                                            AppTypography.responsiveFontSize(
                                              context,
                                              mobile: 15.0,
                                              tablet: 17.0,
                                              desktop: 18.0,
                                            ),
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      backgroundColor: colorScheme.primary,
                                      elevation: AppElevation.responsive(
                                        context,
                                      ),
                                      shadowColor: colorScheme.primary
                                          .withAlpha(102), // 0.4 alpha
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppBreakpoints.isMobile(context)
                                              ? 25
                                              : 28,
                                        ),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        vertical: AppSpacing.md,
                                        horizontal: AppSpacing.lg,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Bottom section - pushed to bottom of screen
                          Padding(
                            padding: EdgeInsets.only(bottom: AppSpacing.md),
                            child: AnimatedBuilder(
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
                                    size: AppSizing.responsiveIconSize(
                                      context,
                                      mobile: 14,
                                      tablet: 16,
                                      desktop: 18,
                                    ),
                                    color: colorScheme.onSurface.withAlpha(
                                      102,
                                    ), // 0.4 alpha
                                  ),
                                  SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        'Supported sites: AllRecipes, Instagram, Food Network, BBC Food, and more!',
                                        style: TextStyle(
                                          fontSize:
                                              AppTypography.responsiveCaptionSize(
                                                context,
                                              ),
                                          color: colorScheme.onSurface
                                              .withAlpha(128), // 0.5 alpha
                                          fontStyle: FontStyle.italic,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              FloatingBottomBar(),
              FloatingButton(
                tooltip: 'New Recipe',
                onPressed:
                    () => Navigator.pushNamed(
                      context,
                      '/recipeEdit',
                      arguments: Recipe(title: 'New Recipe', toEdit: false),
                    ),
                icon: Icons.add_rounded,
              ),
            ],
          );
        },
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
