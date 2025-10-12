import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:recipease/components/custom_app_bar.dart';
import 'package:recipease/components/floating_bottom_bar.dart';
import 'package:recipease/providers/recipe_provider.dart';
import 'package:recipease/providers/subscription_provider.dart';
import 'package:recipease/services/credits_service.dart';
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

  // no-op placeholder removed (was unused)

  void _handleDietaryPreferences(List<String> preferences) {
    setState(() {
      _dietaryRestrictions.clear();
      _dietaryRestrictions.addAll(preferences);
    });
  }

  void _showInsufficientCreditsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Insufficient Credits'),
            content: const Text(
              'You don\'t have enough credits to generate recipes. Please purchase credits or subscribe to continue.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/subscription');
                },
                child: const Text('Get Credits'),
              ),
            ],
          ),
    );
  }

  void _loadRecipes(BuildContext context) async {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    final subscriptionProvider = Provider.of<SubscriptionProvider>(
      context,
      listen: false,
    );

    // Check if user has enough credits
    final hasCredits = await subscriptionProvider.hasEnoughCredits(
      CreditType.recipeGeneration,
    );

    if (!hasCredits && !subscriptionProvider.isPremium) {
      if (context.mounted) {
        _showInsufficientCreditsDialog(context);
      }
      return;
    }

    try {
      // Show enhanced loading overlay
      if (context.mounted) {
        showGeneralDialog(
          context: context,
          barrierLabel: 'Generating Recipes',
          barrierColor: Colors.black.withValues(alpha: 0.25),
          barrierDismissible: false,
          transitionDuration: const Duration(milliseconds: 220),
          pageBuilder: (context, animation, secondaryAnimation) {
            return const SizedBox.shrink();
          },
          transitionBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 8.0 * curved.value,
                sigmaY: 8.0 * curved.value,
              ),
              child: Opacity(
                opacity: animation.value,
                child: Transform.scale(
                  scale: 0.98 + 0.02 * curved.value,
                  child: Center(child: _GeneratingRecipesDialog()),
                ),
              ),
            );
          },
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
        // Use credits for recipe generation (if not premium)
        if (!subscriptionProvider.isPremium) {
          await subscriptionProvider.useCredits(
            CreditType.recipeGeneration,
            reason: 'AI recipe generation',
          );
        }

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recipes generated successfully!',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(
                  alpha: Theme.of(context).colorScheme.alphaVeryHigh,
                ),
              ),
            ),
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
                                  'Recipe Generator',
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
                                        color: colorScheme.onSurface,
                                        fontSize:
                                            AppTypography.responsiveFontSize(
                                              context,
                                            ),
                                      ),
                                      labelStyle: TextStyle(
                                        color: colorScheme.onSurface,
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
                                                    64,
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
                                      width: double.infinity,
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
                                                    .withAlpha(64)
                                                : Theme.of(
                                                  context,
                                                ).colorScheme.surface,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withAlpha(20),
                                            blurRadius:
                                                AppBreakpoints.isMobile(context)
                                                    ? 15
                                                    : 20,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
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
                                                    .withAlpha(64)
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .surface
                                                    .withValues(
                                                      alpha:
                                                          Theme.of(context)
                                                              .colorScheme
                                                              .alphaVeryHigh,
                                                    ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withAlpha(20),
                                            blurRadius:
                                                AppBreakpoints.isMobile(context)
                                                    ? 15
                                                    : 20,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: DropdownButton<String>(
                                        value: _cuisineType,
                                        style: TextStyle(
                                          fontSize:
                                              AppTypography.responsiveFontSize(
                                                context,
                                              ),
                                          color: colorScheme.onSurface,
                                        ),
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
                                    Text.rich(
                                      TextSpan(
                                        text: 'Cooking Time: ',
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
                                        children: [
                                          TextSpan(
                                            text:
                                                '${_cookingTime.round()} minutes',
                                            style: TextStyle(
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                        ],
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
                                    icon: Icon(
                                      Icons.auto_awesome_rounded,
                                      size: AppSizing.responsiveIconSize(
                                        context,
                                        mobile: 20,
                                        tablet: 22,
                                        desktop: 24,
                                      ),
                                      color: colorScheme.surface,
                                    ),
                                    label: Text(
                                      'Generate Recipes',
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
                                        color: colorScheme.surface,
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
                                    'Recipes are generated based on your preferences and available ingredients',
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

class _GeneratingRecipesDialog extends StatefulWidget {
  const _GeneratingRecipesDialog();

  @override
  State<_GeneratingRecipesDialog> createState() =>
      _GeneratingRecipesDialogState();
}

class _GeneratingRecipesDialogState extends State<_GeneratingRecipesDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.96,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      type: MaterialType.transparency,
      child: ScaleTransition(
        scale: _pulse,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            color:
                theme.brightness == Brightness.dark
                    ? cs.surfaceContainerHigh.withValues(alpha: 0.9)
                    : cs.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
            border: Border.all(
              color: cs.primary.withValues(alpha: 0.12),
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _AnimatedDotsTitle(title: 'Generating Recipes'),
              const SizedBox(height: 10),
              Text(
                'Whisking ideas, simmering flavors, and plating suggestions...',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  backgroundColor: cs.primary.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedDotsTitle extends StatefulWidget {
  final String title;
  const _AnimatedDotsTitle({required this.title});

  @override
  State<_AnimatedDotsTitle> createState() => _AnimatedDotsTitleState();
}

class _AnimatedDotsTitleState extends State<_AnimatedDotsTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = (_controller.value * 3).floor();
        final dots = ''.padRight((t % 3) + 1, '.');
        return Text(
          '${widget.title}$dots',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        );
      },
    );
  }
}
