import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipease/components/custom_app_bar.dart';
import 'package:recipease/providers/recipe_provider.dart';
import 'package:recipease/providers/subscription_provider.dart';
import 'package:recipease/services/credits_service.dart';
import 'package:recipease/components/checkbox_list.dart';
import 'package:recipease/theme/theme.dart';
import '../components/error_display.dart';
import '../utils/snackbar_helper.dart';
import '../utils/loading_dialog_helper.dart';
import '../utils/error_utils.dart';
import '../components/offline_banner.dart';
import '../components/inline_banner_ad.dart';
import '../main.dart';

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
      duration: const Duration(milliseconds: 300),
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

    // Check if user has enough credits (required for all users)
    final hasCredits = await subscriptionProvider.hasEnoughCredits(
      CreditType.recipeGeneration,
    );

    if (!hasCredits) {
      if (context.mounted) {
        _showInsufficientCreditsDialog(context);
      }
      return;
    }

    try {
      // Show loading dialog
      debugPrint('🔵 [Generate] About to show loading dialog');
      if (context.mounted) {
        LoadingDialogHelper.show(context, message: 'Generating Recipes');
        debugPrint('🔵 [Generate] Loading dialog shown');
      }

      debugPrint(
        '🔵 [Generate] Calling generateRecipes with ${_ingredients.length} ingredients',
      );
      await recipeProvider.generateRecipes(
        ingredients: _ingredients,
        dietaryRestrictions: _dietaryRestrictions,
        cuisineType: _cuisineType,
      );
      debugPrint('🔵 [Generate] generateRecipes completed');
      debugPrint(
        '🔵 [Generate] AI Generated recipes count: ${recipeProvider.aiGeneratedRecipes.length}',
      );

      // Close loading dialog
      if (context.mounted) {
        LoadingDialogHelper.dismiss(context);
      }

      if (context.mounted && recipeProvider.aiGeneratedRecipes.isNotEmpty) {
        // Always deduct one generation credit after successful generation
        // Only deduct if user doesn't have unlimited usage or active trial
        await subscriptionProvider.useCredits(
          CreditType.recipeGeneration,
          reason: 'AI recipe generation',
        );

        // Refresh credits display to show updated balance
        await subscriptionProvider.refreshData();

        // Show success message
        if (context.mounted) {
          SnackBarHelper.showSuccess(
            context,
            'Recipes generated successfully!',
          );

          // Navigate to generated recipes screen
          Navigator.pushNamed(context, '/generatedRecipes');
        }
      } else if (context.mounted) {
        // Show error message if no recipes were generated
        SnackBarHelper.showError(
          context,
          'No recipes were generated. Please try again.',
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
                    ErrorUtils.isNetworkError(e.toString())
                        ? 'Connection issue. Please check your internet and try again.'
                        : 'Unable to generate recipes. Please try again.',
                isNetworkError: ErrorUtils.isNetworkError(e.toString()),
                isAuthError: ErrorUtils.isAuthError(e.toString()),
                isFormatError: ErrorUtils.isFormatError(e.toString()),
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
      appBar: const CustomAppBar(
        title: 'Generate',
        fullTitle: 'Generate Recipe',
      ),
      body: Consumer<RecipeProvider>(
        builder: (context, recipeProvider, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Background aligned to global scaffold background with subtle pattern
              Positioned.fill(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: CustomPaint(
                    painter: _BackgroundPatternPainter(
                      color: colorScheme.primary.withAlpha(8), // 0.03 alpha
                    ),
                  ),
                ),
              ),

              // Main content
              Positioned.fill(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          MediaQuery.of(context).size.height -
                          MediaQuery.of(context).padding.top -
                          kToolbarHeight -
                          MediaQuery.of(context).padding.bottom,
                      maxWidth: () {
                        // Narrower width for large screens
                        if (AppBreakpoints.isDesktop(context)) {
                          return 600.0; // Narrow width for desktop
                        }
                        if (AppBreakpoints.isTablet(context)) {
                          return 600.0; // Same for tablet
                        }
                        return double.infinity; // Full width for mobile
                      }(),
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      controller: _scrollController,
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: AppSpacing.responsive(context),
                          right: AppSpacing.responsive(context),
                          top: AppSpacing.responsive(context),
                          bottom:
                              AppSpacing.responsive(context) +
                              30, // Extra space for floating bar
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Main content section
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Show spacing only when ads are hidden (premium users or debug mode)
                                Consumer<SubscriptionProvider>(
                                  builder: (context, subscriptionProvider, _) {
                                    if (hideAds ||
                                        subscriptionProvider.isPremium) {
                                      return SizedBox(
                                        height: size.height * 0.08,
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),

                                // Inline banner ad above hero icon
                                const InlineBannerAd(),

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
                                        (_animationController.value - 0.3) /
                                        0.7;
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
                                        (_animationController.value - 0.4) /
                                        0.6;
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
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .surface
                                                    .withValues(
                                                      alpha:
                                                          Theme.of(context)
                                                              .colorScheme
                                                              .alphaVeryHigh,
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
                                            color: colorScheme.outline
                                                .withAlpha(26), // 0.1 alpha
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
                                            color: colorScheme.primary
                                                .withAlpha(128), // 0.5 alpha
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
                                                      .withAlpha(
                                                        26,
                                                      ), // 0.1 alpha
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
                                        (_animationController.value - 0.6) /
                                        0.4;
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                              theme.brightness ==
                                                      Brightness.dark
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
                                                  AppBreakpoints.isMobile(
                                                        context,
                                                      )
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
                                        (_animationController.value - 0.7) /
                                        0.3;
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                              theme.brightness ==
                                                      Brightness.dark
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
                                                  AppBreakpoints.isMobile(
                                                        context,
                                                      )
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
                                        (_animationController.value - 0.8) /
                                        0.2;
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        (_animationController.value - 0.9) /
                                        0.1;
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
                                        shadowColor: Colors.deepPurple
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

                                SizedBox(height: AppSpacing.xxl),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Offline banner at the top (after content so it appears on top)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: OfflineBanner(),
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
