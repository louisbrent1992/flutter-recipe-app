import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:recipease/components/custom_app_bar.dart';

import 'package:recipease/models/recipe.dart';
import 'package:recipease/providers/recipe_provider.dart';
import 'package:recipease/providers/subscription_provider.dart';
import 'package:recipease/services/credits_service.dart';
import 'package:recipease/config/app_config.dart';
import 'package:recipease/theme/theme.dart';
import '../utils/loading_dialog_helper.dart';
import '../utils/snackbar_helper.dart';
import '../components/offline_banner.dart';
import '../components/inline_banner_ad.dart';
import '../main.dart';

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
  bool _startedFromShare = false;

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

    // Set the URL from shared intent if available
    if (widget.sharedUrl != null && widget.sharedUrl!.isNotEmpty) {
      _startedFromShare = true;
      _urlController.text = widget.sharedUrl!;

      // Auto import if URL is provided
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _importRecipe(context, widget.sharedUrl!),
      );
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pasteUrl(BuildContext context) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted) return;
      if (clipboardData != null &&
          clipboardData.text != null &&
          clipboardData.text!.isNotEmpty) {
        _urlController.text = clipboardData.text!;
        // Show a brief feedback
        messenger.showSnackBar(
          SnackBar(
            content: const Text('URL pasted'),
            backgroundColor: theme.colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Clipboard is empty'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Failed to paste from clipboard'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showInsufficientCreditsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Insufficient Credits'),
            content: const Text(
              'You don\'t have enough credits to import recipes. Please purchase credits or subscribe to continue.',
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

    // Ensure context is still mounted and providers are available
    if (!context.mounted) {
      debugPrint('Context not mounted, skipping import');
      return;
    }

    // Wait a moment to ensure providers are fully initialized
    await Future.delayed(Duration(milliseconds: AppConfig.importDelayMs));

    if (!context.mounted) {
      debugPrint('Context not mounted after delay, skipping import');
      return;
    }

    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    final subscriptionProvider = Provider.of<SubscriptionProvider>(
      context,
      listen: false,
    );

    // Check if user has enough credits (required for all users)
    final hasCredits = await subscriptionProvider.hasEnoughCredits(
      CreditType.recipeImport,
    );

    if (!hasCredits) {
      if (context.mounted) {
        _showInsufficientCreditsDialog(context);
      }
      return;
    }

    try {
      // Show loading dialog
      if (context.mounted) {
        LoadingDialogHelper.show(context, message: 'Importing Recipe');
      }

      if (context.mounted) {
        final result = await recipeProvider.importRecipeFromUrl(url, context);

        // Close loading dialog
        if (context.mounted) {
          LoadingDialogHelper.dismiss(context);
        }

        if (context.mounted && result != null) {
          final recipe = result['recipe'];
          final fromCache = result['fromCache'] as bool? ?? false;

          // Only deduct credit if recipe was NOT from cache
          if (!fromCache) {
            await subscriptionProvider.useCredits(
              CreditType.recipeImport,
              reason: 'Recipe import from URL',
            );
          }

          // Show success message
          if (context.mounted) {
            SnackBarHelper.showSuccess(
              context,
              fromCache
                  ? 'Recipe loaded from cache (no credit charged)!'
                  : 'Recipe imported successfully!',
            );

            // Navigate to details screen
            _navigateToRecipeDetails(recipe);
          }
        }
      }
    } catch (e) {
      // Close loading dialog if it's still showing
      if (context.mounted) {
        LoadingDialogHelper.dismiss(context);
      }
      if (context.mounted) {
        SnackBarHelper.showError(context, 'Error: ${e.toString()}');
      }
    }
  }

  Future<void> _navigateToRecipeDetails(Recipe recipe) async {
    if (mounted) {
      if (_startedFromShare) {
        Navigator.pushReplacementNamed(
          context,
          '/recipeEdit',
          arguments: recipe,
        );
      } else {
        Navigator.pushNamed(context, '/recipeEdit', arguments: recipe);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Import',
        fullTitle: 'Import Recipe',
        floatingButtons: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'More options',
            onSelected: (value) {
              switch (value) {
                case 'new_recipe':
                  Navigator.pushNamed(
                    context,
                    '/recipeEdit',
                    arguments: Recipe(title: 'New Recipe', toEdit: false),
                  );
                  break;
                case 'clear_url':
                  _urlController.clear();
                  break;
                case 'paste_url':
                  _pasteUrl(context);
                  break;
              }
            },
            itemBuilder:
                (BuildContext context) => [
                  PopupMenuItem<String>(
                    value: 'new_recipe',
                    child: Row(
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        const Text('New Recipe'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'paste_url',
                    child: Row(
                      children: [
                        Icon(
                          Icons.paste_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        const Text('Paste URL'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'clear_url',
                    child: Row(
                      children: [
                        Icon(
                          Icons.clear_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(width: 12),
                        const Text('Clear URL'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: Consumer<RecipeProvider>(
        builder: (context, recipeProvider, _) {
          return Stack(
            fit: StackFit.expand,

            children: [
              // Offline banner at the top
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: OfflineBanner(),
              ),

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
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
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
                          mainAxisAlignment: MainAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Main content section
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Show spacing only when ads are hidden (premium users or debug mode)
                                Consumer<SubscriptionProvider>(
                                  builder: (context, subscriptionProvider, _) {
                                    if (hideAds || subscriptionProvider.isPremium) {
                                      return SizedBox(height: size.height * 0.08);
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
                                      opacity: (_animationController.value -
                                              0.3)
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
                                          color: colorScheme.onSurface
                                              .withAlpha(179), // 0.7 alpha
                                        ),
                                        children: [
                                          const TextSpan(text: 'Tap the '),
                                          WidgetSpan(
                                            child: Icon(
                                              Icons.share,
                                              size:
                                                  AppSizing.responsiveIconSize(
                                                    context,
                                                    mobile: 16,
                                                    tablet: 18,
                                                    desktop: 20,
                                                  ),
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                          const TextSpan(
                                            text: ' share button (Android) or ',
                                          ),
                                          WidgetSpan(
                                            child: Icon(
                                              Icons.ios_share,
                                              size:
                                                  AppSizing.responsiveIconSize(
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
                                                ' share button (iOS) in your favorite social media app, or paste a recipe URL below to import recipes. You can also create a recipe manually using the ',
                                          ),
                                          WidgetSpan(
                                            child: Icon(
                                              Icons.more_vert_rounded,
                                              size:
                                                  AppSizing.responsiveIconSize(
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
                                                ' menu at the top of your screen.',
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
                                      opacity: (_animationController.value -
                                              0.4)
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
                                      maxLines: null,
                                      decoration: InputDecoration(
                                        hintText:
                                            'Paste recipe URL here\nSupported: AllRecipes, Instagram, TikTok, YouTube, Food Network, BBC Food, and more',
                                        hintStyle: TextStyle(
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.5),
                                          fontSize:
                                              AppTypography.responsiveFontSize(
                                                context,
                                              ),
                                          height: 1.4,
                                        ),
                                        hintMaxLines: 3,
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
                                      opacity: (_animationController.value -
                                              0.6)
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
                                      icon: Icon(
                                        Icons.download_rounded,
                                        size: AppSizing.responsiveIconSize(
                                          context,
                                          mobile: 20,
                                          tablet: 22,
                                          desktop: 24,
                                        ),
                                      ),
                                      label: Text(
                                        'Import Recipe',
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
