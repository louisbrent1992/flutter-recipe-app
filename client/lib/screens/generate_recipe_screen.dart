import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipease/components/custom_app_bar.dart';
import 'package:recipease/components/floating_bottom_bar.dart';
import 'package:recipease/providers/recipe_provider.dart';
import 'package:recipease/components/checkbox_list.dart';
import 'package:recipease/theme/theme.dart';
import '../components/error_display.dart';

class GenerateRecipeScreen extends StatefulWidget {
  const GenerateRecipeScreen({super.key});

  @override
  GenerateRecipeScreenState createState() => GenerateRecipeScreenState();
}

class GenerateRecipeScreenState extends State<GenerateRecipeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _ingredientController = TextEditingController();
  final List<String> _ingredients = [];
  final List<String> _dietaryRestrictions = [];
  String _cuisineType = 'Random';
  double _cookingTime = 30;
  final ScrollController _scrollController = ScrollController();
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
  }

  void _addIngredient() {
    if (_ingredientController.text.isNotEmpty && mounted) {
      setState(() {
        _ingredients.addAll(
          _ingredientController.text
              .split(',')
              .map((ingredient) => ingredient.trim()),
        );
        _ingredientController.clear();
      });
    }
  }

  void _handleDietaryPreferences(List<String> preferences) {
    setState(() {
      _dietaryRestrictions.clear();
      _dietaryRestrictions.addAll(preferences);
    });
  }

  void _loadRecipes(BuildContext context) async {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);

    try {
      // Show loading indicator
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Generating Recipes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(),
                  ],
                ),
              ),
        );
      }

      await recipeProvider.generateRecipes(
        ingredients: _ingredients,
        dietaryRestrictions: _dietaryRestrictions,
        cuisineType: _cuisineType,
      );

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (context.mounted && recipeProvider.generatedRecipes.isNotEmpty) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipes generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to generated recipes screen
        Navigator.pushNamed(context, '/generatedRecipes');
      } else if (context.mounted) {
        // Show error message if no recipes were generated
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No recipes were generated. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if it's still showing
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (context.mounted) {
        showDialog(
          context: context,
          builder:
              (context) => ErrorDisplay(
                message:
                    e.toString().contains('Connection error')
                        ? 'Unable to connect to server. Please check your internet connection.'
                        : 'Error generating recipes: ${e.toString()}',
                isNetworkError:
                    e.toString().toLowerCase().contains('connection') ||
                    e.toString().toLowerCase().contains('network'),
                isAuthError:
                    e.toString().toLowerCase().contains('auth') ||
                    e.toString().toLowerCase().contains('login'),
                isFormatError:
                    e.toString().toLowerCase().contains('format') ||
                    e.toString().toLowerCase().contains('parse'),
                onRetry: () {
                  Navigator.pop(context);
                  _loadRecipes(context);
                },
              ),
        );
      }
    }
  }

  @override
  void dispose() {
    _ingredientController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Generate Recipe',
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
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
                  controller: _scrollController,
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
                                    color: Colors.deepPurple.withAlpha(
                                      77,
                                    ), // 0.3 alpha
                                    borderRadius: BorderRadius.circular(
                                      AppBreakpoints.isMobile(context)
                                          ? 16
                                          : 20,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    size: AppSizing.responsiveIconSize(
                                      context,
                                      mobile: 35,
                                      tablet: 40,
                                      desktop: 45,
                                    ),
                                    color: Colors.deepPurple,
                                  ),
                                ),
                              ),

                              SizedBox(height: AppSpacing.lg),

                              // Title animation
                              FadeTransition(
                                opacity: _fadeInAnimation,
                                child: Text(
                                  'AI Recipe Generator',
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
                                  final progress =
                                      (_animationController.value - 0.3) / 0.7;
                                  final opacity = progress.clamp(0.0, 1.0);
                                  final translateY = 30 * (1 - opacity);
                                  return Opacity(
                                    opacity: opacity,
                                    child: Transform.translate(
                                      offset: Offset(0, translateY),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: AppSpacing.horizontalResponsive(
                                    context,
                                  ),
                                  child: Text(
                                    'Enter your ingredients, dietary preferences, and cooking time to generate personalized recipes.',
                                    style: TextStyle(
                                      fontSize:
                                          AppTypography.responsiveFontSize(
                                            context,
                                          ),
                                      color: colorScheme.onSurface.withAlpha(
                                        179,
                                      ), // 0.7 alpha
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),

                              SizedBox(height: AppSpacing.xxl),

                              // Ingredients Input field with animation
                              AnimatedBuilder(
                                animation: _animationController,
                                builder: (context, child) {
                                  final progress =
                                      (_animationController.value - 0.4) / 0.6;
                                  final opacity = progress.clamp(0.0, 1.0);
                                  final translateY = 40 * (1 - opacity);
                                  return Opacity(
                                    opacity: opacity,
                                    child: Transform.translate(
                                      offset: Offset(0, translateY),
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
                                    controller: _ingredientController,
                                    decoration: InputDecoration(
                                      hintText: 'gluten-free, chicken, eggs',
                                      labelText: 'Enter ingredients',
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
                                              : Theme.of(
                                                context,
                                              ).colorScheme.surface.withValues(
                                                alpha:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.alphaVeryHigh,
                                              ),
                                      prefixIcon: Icon(
                                        Icons.restaurant_rounded,
                                        color: colorScheme.primary,
                                        size: AppSizing.responsiveIconSize(
                                          context,
                                          mobile: 20,
                                          tablet: 22,
                                          desktop: 24,
                                        ),
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          Icons.add_circle_rounded,
                                          size: AppSizing.responsiveIconSize(
                                            context,
                                            mobile: 20,
                                            tablet: 22,
                                            desktop: 24,
                                          ),
                                          color: colorScheme.primary,
                                        ),
                                        onPressed: _addIngredient,
                                      ),
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
                                    onSubmitted: (value) => _addIngredient(),
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

                              // Ingredients chips
                              if (_ingredients.isNotEmpty) ...[
                                SizedBox(height: AppSpacing.md),
                                AnimatedBuilder(
                                  animation: _animationController,
                                  builder: (context, child) {
                                    final progress =
                                        (_animationController.value - 0.5) /
                                        0.5;
                                    final opacity = progress.clamp(0.0, 1.0);
                                    return Opacity(
                                      opacity: opacity,
                                      child: child,
                                    );
                                  },
                                  child: Wrap(
                                    spacing: 8.0,
                                    runSpacing: 8.0,
                                    children:
                                        _ingredients
                                            .map(
                                              (ingredient) => Chip(
                                                label: Text(
                                                  ingredient,
                                                  style: TextStyle(
                                                    fontSize:
                                                        AppTypography.responsiveFontSize(
                                                          context,
                                                          mobile: 12.0,
                                                          tablet: 14.0,
                                                          desktop: 16.0,
                                                        ),
                                                  ),
                                                ),
                                                backgroundColor: colorScheme
                                                    .primary
                                                    .withAlpha(26), // 0.1 alpha
                                                deleteIcon: Icon(
                                                  Icons.close,
                                                  size:
                                                      AppSizing.responsiveIconSize(
                                                        context,
                                                        mobile: 16,
                                                        tablet: 18,
                                                        desktop: 20,
                                                      ),
                                                ),
                                                onDeleted: () {
                                                  setState(() {
                                                    _ingredients.remove(
                                                      ingredient,
                                                    );
                                                  });
                                                },
                                              ),
                                            )
                                            .toList(),
                                  ),
                                ),
                              ],

                              SizedBox(height: AppSpacing.lg),

                              // Dietary Preferences with animation
                              AnimatedBuilder(
                                animation: _animationController,
                                builder: (context, child) {
                                  final progress =
                                      (_animationController.value - 0.6) / 0.4;
                                  final opacity = progress.clamp(0.0, 1.0);
                                  final translateY = 20 * (1 - opacity);
                                  return Opacity(
                                    opacity: opacity,
                                    child: Transform.translate(
                                      offset: Offset(0, translateY),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Dietary Preferences:',
                                      style: TextStyle(
                                        fontSize:
                                            AppTypography.responsiveHeadingSize(
                                              context,
                                              mobile: 18.0,
                                              tablet: 20.0,
                                              desktop: 22.0,
                                            ),
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    SizedBox(height: AppSpacing.sm),
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          AppBreakpoints.isMobile(context)
                                              ? 12
                                              : 16,
                                        ),
                                        color:
                                            theme.brightness == Brightness.dark
                                                ? colorScheme
                                                    .surfaceContainerHighest
                                                    .withAlpha(128)
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .surface
                                                    .withValues(
                                                      alpha:
                                                          Theme.of(context)
                                                              .colorScheme
                                                              .alphaVeryHigh,
                                                    ),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                        vertical: AppSpacing.sm,
                                      ),
                                      child: DietaryPreferenceCheckboxList(
                                        label: 'Select Preferences',
                                        selectedPreferences:
                                            _dietaryRestrictions,
                                        onChanged: _handleDietaryPreferences,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: AppSpacing.lg),

                              // Cuisine Type with animation
                              AnimatedBuilder(
                                animation: _animationController,
                                builder: (context, child) {
                                  final progress =
                                      (_animationController.value - 0.7) / 0.3;
                                  final opacity = progress.clamp(0.0, 1.0);
                                  final translateY = 20 * (1 - opacity);
                                  return Opacity(
                                    opacity: opacity,
                                    child: Transform.translate(
                                      offset: Offset(0, translateY),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Cuisine Type:',
                                      style: TextStyle(
                                        fontSize:
                                            AppTypography.responsiveHeadingSize(
                                              context,
                                              mobile: 18.0,
                                              tablet: 20.0,
                                              desktop: 22.0,
                                            ),
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    SizedBox(height: AppSpacing.sm),
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          AppBreakpoints.isMobile(context)
                                              ? 12
                                              : 16,
                                        ),
                                        color:
                                            theme.brightness == Brightness.dark
                                                ? colorScheme
                                                    .surfaceContainerHighest
                                                    .withAlpha(128)
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .surface
                                                    .withValues(
                                                      alpha:
                                                          Theme.of(context)
                                                              .colorScheme
                                                              .alphaVeryHigh,
                                                    ),
                                      ),
                                      child: DropdownButton<String>(
                                        value: _cuisineType,
                                        onChanged: (String? newValue) {
                                          setState(() {
                                            _cuisineType = newValue!;
                                          });
                                        },
                                        items:
                                            <String>[
                                              'Random',
                                              'American',
                                              'Italian',
                                              'Chinese',
                                              'Mexican',
                                              'Indian',
                                              'Japanese',
                                              'French',
                                              'Spanish',
                                              'Thai',
                                              'Greek',
                                              'Turkish',
                                              'Vietnamese',
                                              'Korean',
                                              'German',
                                              'Polish',
                                              'Portuguese',
                                              'Russian',
                                              'Brazilian',
                                              'Dutch',
                                              'Belgian',
                                              'Swedish',
                                              'Norwegian',
                                              'Danish',
                                            ].map<DropdownMenuItem<String>>((
                                              String value,
                                            ) {
                                              return DropdownMenuItem<String>(
                                                value: value,
                                                child: Text(
                                                  value,
                                                  style: TextStyle(
                                                    fontSize:
                                                        AppTypography.responsiveFontSize(
                                                          context,
                                                        ),
                                                    color:
                                                        colorScheme.onSurface,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                        isExpanded: true,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: AppSpacing.md,
                                          vertical: AppSpacing.sm,
                                        ),
                                        underline: Container(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: AppSpacing.lg),

                              // Cooking Time with animation
                              AnimatedBuilder(
                                animation: _animationController,
                                builder: (context, child) {
                                  final progress =
                                      (_animationController.value - 0.8) / 0.2;
                                  final opacity = progress.clamp(0.0, 1.0);
                                  final translateY = 20 * (1 - opacity);
                                  return Opacity(
                                    opacity: opacity,
                                    child: Transform.translate(
                                      offset: Offset(0, translateY),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Cooking Time: ${_cookingTime.round()} minutes',
                                      style: TextStyle(
                                        fontSize:
                                            AppTypography.responsiveHeadingSize(
                                              context,
                                              mobile: 18.0,
                                              tablet: 20.0,
                                              desktop: 22.0,
                                            ),
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    SizedBox(height: AppSpacing.sm),
                                    Slider.adaptive(
                                      value: _cookingTime,
                                      min: 0,
                                      max: 120,
                                      divisions: 12,
                                      activeColor: colorScheme.primary,
                                      inactiveColor: colorScheme.primary
                                          .withAlpha(51), // 0.2 alpha
                                      onChanged: (double value) {
                                        setState(() {
                                          _cookingTime = value;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: AppSpacing.xxl),

                              // Generate button with animation
                              AnimatedBuilder(
                                animation: _animationController,
                                builder: (context, child) {
                                  final progress =
                                      (_animationController.value - 0.9) / 0.1;
                                  final opacity = progress.clamp(0.0, 1.0);
                                  final translateY = 30 * (1 - opacity);
                                  return Opacity(
                                    opacity: opacity,
                                    child: Transform.translate(
                                      offset: Offset(0, translateY),
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
                                        recipeProvider.isLoading
                                            ? null
                                            : () => _loadRecipes(context),
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
                                                valueColor: AlwaysStoppedAnimation<
                                                  Color
                                                >(
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .surface
                                                      .withValues(
                                                        alpha:
                                                            Theme.of(context)
                                                                .colorScheme
                                                                .alphaVeryHigh,
                                                      ),
                                                ),
                                              ),
                                            )
                                            : Icon(
                                              Icons.auto_awesome_rounded,
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
                                          ? 'Generating...'
                                          : 'Generate Recipes',
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
                                      foregroundColor: Theme.of(
                                        context,
                                      ).colorScheme.surface.withValues(
                                        alpha:
                                            Theme.of(
                                              context,
                                            ).colorScheme.alphaVeryHigh,
                                      ),
                                      backgroundColor: Colors.deepPurple,
                                      elevation: AppElevation.responsive(
                                        context,
                                      ),
                                      shadowColor: Colors.deepPurple.withAlpha(
                                        102,
                                      ), // 0.4 alpha
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

                              SizedBox(height: AppSpacing.xxl),
                            ],
                          ),

                          // Bottom section - pushed to bottom of screen
                          Padding(
                            padding: EdgeInsets.only(bottom: AppSpacing.md),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                  child: Text(
                                    'AI will create recipes based on your preferences and available ingredients',
                                    style: TextStyle(
                                      fontSize:
                                          AppTypography.responsiveCaptionSize(
                                            context,
                                          ),
                                      color: colorScheme.onSurface.withAlpha(
                                        128,
                                      ), // 0.5 alpha
                                      fontStyle: FontStyle.italic,
                                    ),
                                    textAlign: TextAlign.left,
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
              ),
              FloatingBottomBar(),
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
