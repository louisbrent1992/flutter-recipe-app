import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../theme/theme.dart';
import '../providers/recipe_provider.dart';
import '../models/recipe.dart';
import 'dart:ui';

class NavDrawer extends StatefulWidget {
  const NavDrawer({super.key});

  @override
  State<NavDrawer> createState() => _NavDrawerState();
}

class _NavDrawerState extends State<NavDrawer> with TickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  late List<AnimationController> _itemControllers;
  late List<Animation<double>> _itemSlideAnimations;
  late List<Animation<double>> _itemFadeAnimations;

  // Get actual user data from RecipeProvider
  int get savedRecipesCount {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    return recipeProvider.userRecipes.length;
  }

  List<String> get recipeDifficulties {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    return recipeProvider.userRecipes
        .map((recipe) => recipe.difficulty.toLowerCase())
        .where((difficulty) => difficulty.isNotEmpty)
        .toList();
  }

  // Calculate chef ranking based on difficulty and recipe count
  Map<String, dynamic> get chefRanking {
    int stars = 0;

    // Calculate average difficulty stars (1-3)
    if (recipeDifficulties.isNotEmpty) {
      double avgDifficulty =
          recipeDifficulties
              .map((difficulty) {
                switch (difficulty.toLowerCase()) {
                  case 'easy':
                    return 1.0;
                  case 'medium':
                    return 1.5;
                  case 'hard':
                    return 2.0;
                  default:
                    return 1.0;
                }
              })
              .reduce((a, b) => a + b) /
          recipeDifficulties.length;

      stars = avgDifficulty.round();
    } else {
      stars = 1; // Default for new users
    }

    // Add bonus stars for recipe count
    if (savedRecipesCount >= 300) {
      stars += 3;
    } else if (savedRecipesCount >= 100) {
      stars += 2;
    } else if (savedRecipesCount >= 50) {
      stars += 1;
    }

    // Ensure stars are between 1 and 5
    stars = stars.clamp(1, 5);

    // Determine title based on stars
    String title;
    String description;
    switch (stars) {
      case 1:
        title = 'Novice Chef';
        description = 'Just getting started';
        break;
      case 2:
        title = 'Home Cook';
        description = 'Building skills';
        break;
      case 3:
        title = 'Skilled Chef';
        description = 'Confident cooking';
        break;
      case 4:
        title = 'Expert Chef';
        description = 'Advanced techniques';
        break;
      case 5:
        title = 'Master Chef';
        description = 'Culinary excellence';
        break;
      default:
        title = 'Chef';
        description = 'Cooking enthusiast';
    }

    return {'stars': stars, 'title': title, 'description': description};
  }

  @override
  void initState() {
    super.initState();

    // Load user recipes if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final recipeProvider = Provider.of<RecipeProvider>(
        context,
        listen: false,
      );
      if (recipeProvider.userRecipes.isEmpty) {
        recipeProvider.loadUserRecipes();
        recipeProvider.loadFavoriteRecipes();
      }
    });

    // Main controllers with smoother timing
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Create individual controllers for staggered animations
    _itemControllers = List.generate(
      10,
      (index) => AnimationController(
        duration: Duration(milliseconds: 600 + (index * 40)),
        vsync: this,
      ),
    );

    // Create smooth slide animations for each item
    _itemSlideAnimations =
        _itemControllers
            .map(
              (controller) => Tween<double>(begin: -1.0, end: 0.0).animate(
                CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
              ),
            )
            .toList();

    // Create fade animations for each item
    _itemFadeAnimations =
        _itemControllers
            .map(
              (controller) => Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(
                  parent: controller,
                  curve: const Interval(0.0, 0.8, curve: Curves.easeOutQuart),
                ),
              ),
            )
            .toList();

    // Start animations with natural timing
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _fadeController.forward();
        _slideController.forward();
      }
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _scaleController.forward();
        _pulseController.repeat(reverse: true);
      }
    });

    // Stagger item animations with smooth timing
    for (int i = 0; i < _itemControllers.length; i++) {
      Future.delayed(Duration(milliseconds: 600 + (i * 120)), () {
        if (mounted) {
          _itemControllers[i].forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _pulseController.dispose();
    for (var controller in _itemControllers) {
      controller.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = AppBreakpoints.isMobile(context);

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    colorScheme.surface,
                    colorScheme.surfaceContainerHighest,
                    colorScheme.secondary.withValues(alpha: 0.1),
                  ]
                : [
                    colorScheme.surface,
                    backgroundColor,
                    neutralColor.withValues(alpha: 0.8),
                  ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Fixed header
              _buildImageHeader(
                context,
                colorScheme,
                isDark,
                isMobile,
                screenHeight,
              ),
              // Scrollable content
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        _buildNavigationContent(context, colorScheme, isDark),
                        _buildFloatingFooter(context, colorScheme, isDark),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageHeader(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
    bool isMobile,
    double screenHeight,
  ) {
    // Responsive header height
    final double headerHeight =
        isMobile ? (screenHeight < 600 ? 190.0 : 210.0) : 230.0;

    return AnimatedBuilder(
      animation: Listenable.merge([_fadeController, _slideController]),
      builder: (context, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: _fadeController,
            curve: Curves.easeOutQuart,
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -1.0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: _slideController,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: Container(
              height: headerHeight,
              margin: EdgeInsets.all(isMobile ? 8 : 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isMobile ? 20 : 28),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.onSurface.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                    spreadRadius: -2,
                  ),
                  BoxShadow(
                    color: colorScheme.onSurface.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isMobile ? 20 : 28),
                child: Stack(
                  children: [
                    // Background Image
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/drawer_header_bg_2.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  primaryColor.withValues(alpha: 0.8),
                                  secondaryColor.withValues(alpha: 0.9),
                                  const Color(
                                    0xFF0F3460,
                                  ).withValues(alpha: 0.7),
                                ],
                                stops: const [0.0, 0.6, 1.0],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Animated gradient overlay
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(
                                    alpha: 0.2 + (_pulseController.value * 0.1),
                                  ),
                                  Colors.black.withValues(alpha: 0.05),
                                  Colors.black.withValues(
                                    alpha: 0.3 + (_pulseController.value * 0.1),
                                  ),
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    // Content
                    Positioned.fill(
                      child: Container(
                        padding: EdgeInsets.all(isMobile ? 12 : 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildAnimatedAvatar(colorScheme, isDark, isMobile),
                            SizedBox(height: isMobile ? 6 : 8),
                            _buildUserInfo(
                              context,
                              colorScheme,
                              isDark,
                              isMobile,
                            ),
                            if (!isMobile || screenHeight > 400) ...[
                              SizedBox(height: isMobile ? 8 : 10),
                              _buildQuickStats(
                                context,
                                colorScheme,
                                isDark,
                                isMobile,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    // Animated decorative badge
                    _buildChefBadge(isMobile),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedAvatar(
    ColorScheme colorScheme,
    bool isDark,
    bool isMobile,
  ) {
    final double avatarSize = isMobile ? 50 : 70;

    return AnimatedBuilder(
      animation: Listenable.merge([_scaleController, _pulseController]),
      builder: (context, child) {
        return Transform.scale(
          scale:
              _scaleController.value * (1.0 + (_pulseController.value * 0.02)),
          child: GestureDetector(
            onTap: () {
              // Navigate to profile page
              Navigator.pushNamed(context, '/settings');
            },
            child: Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.4),
                    Colors.white.withValues(alpha: 0.1),
                  ],
                ),
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: Theme.of(context).colorScheme.alphaVeryHigh),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: isMobile ? 16 : 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                                            color: colorScheme.surface.withValues(alpha: 0.3),
                    blurRadius: isMobile ? 8 : 12,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ClipOval(
                child:
                    user?.photoURL != null
                        ? CachedNetworkImage(
                          imageUrl: user!.photoURL!,
                          fit: BoxFit.cover,
                          placeholder:
                              (context, url) =>
                                  _buildAvatarPlaceholder(isDark, isMobile),
                          errorWidget:
                              (context, url, error) =>
                                  _buildAvatarPlaceholder(isDark, isMobile),
                        )
                        : _buildAvatarPlaceholder(isDark, isMobile),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatarPlaceholder(bool isDark, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, secondaryColor],
        ),
      ),
      child: Center(
        child: Text(
          user?.displayName?.isNotEmpty == true
              ? user!.displayName![0].toUpperCase()
              : 'R',
          style: TextStyle(
            fontSize: isMobile ? 20 : 28, // Reduced font sizes
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.surface.withValues(alpha: Theme.of(context).colorScheme.alphaVeryHigh),
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.3),
                offset: const Offset(1, 1),
                blurRadius: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfo(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
    bool isMobile,
  ) {
    return Column(
      children: [
        Text(
          user?.displayName ?? 'Recipe Enthusiast',
          style: TextStyle(
            fontSize: isMobile ? 16 : 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.7),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: isMobile ? 2 : 4),
        Text(
          user?.email ?? 'chef@recipease.com',
          style: TextStyle(
            fontSize: isMobile ? 11 : 14,
            color: Colors.white.withValues(alpha: 0.9),
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.7),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildQuickStats(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
    bool isMobile,
  ) {
    return Consumer<RecipeProvider>(
      builder: (context, recipeProvider, child) {
        // Calculate collections count (this would come from a collections provider if available)
        int collectionsCount = 3; // Placeholder

        // Calculate cooking streak or total cooking time
        String totalCookingTime = _calculateTotalCookingTime(
          recipeProvider.userRecipes,
        );

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatChip(
              savedRecipesCount.toString(),
              'Recipes',
              Icons.restaurant_menu_rounded,
              isDark,
              isMobile,
              () {
                // Navigate to the recipes page
                Navigator.pushNamed(context, '/myRecipes');
              },
            ),
            _buildStatChip(
              totalCookingTime,
              'Cook Time',
              Icons.schedule,
              isDark,
              isMobile,
              null,
            ),
            _buildStatChip(
              collectionsCount.toString(),
              'Collections',
              Icons.collections_bookmark,
              isDark,
              isMobile,
              () {
                // Navigate to the collecitons page
                Navigator.pushNamed(context, '/collections');
              },
            ),
          ],
        );
      },
    );
  }

  String _calculateTotalCookingTime(List<Recipe> recipes) {
    if (recipes.isEmpty) return '0h';

    int totalMinutes = 0;
    for (Recipe recipe in recipes) {
      // Parse cooking time (assuming format like "30", "45 min", "1 hour", etc.)
      String cookingTime = recipe.cookingTime.toLowerCase().replaceAll(
        RegExp(r'[^\d]'),
        '',
      );
      if (cookingTime.isNotEmpty) {
        totalMinutes += int.tryParse(cookingTime) ?? 0;
      }
    }

    if (totalMinutes < 60) {
      return '${totalMinutes}m';
    } else {
      int hours = totalMinutes ~/ 60;
      int remainingMinutes = totalMinutes % 60;
      if (remainingMinutes == 0) {
        return '${hours}h';
      } else {
        return '${hours}h ${remainingMinutes}m';
      }
    }
  }

  Widget _buildStatChip(
    String value,
    String label,
    IconData icon,
    bool isDark,
    bool isMobile,
    GestureTapCallback? onTap,
  ) {
    return Flexible(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 6 : 10,
            vertical: isMobile ? 3 : 5,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isMobile ? 14 : 18),
            color: Colors.white.withValues(alpha: 0.2),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: isMobile ? 10 : 14, color: Colors.white),
              SizedBox(height: isMobile ? 1 : 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: isMobile ? 9 : 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.7),
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: isMobile ? 7 : 9,
                  color: Colors.white.withValues(alpha: 0.9),
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.7),
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChefBadge(bool isMobile) {
    final ranking = chefRanking;
    final int stars = ranking['stars'];
    final String title = ranking['title'];

    return AnimatedBuilder(
      animation: _scaleController,
      builder: (context, child) {
        return Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: () {
              // Show detailed ranking info
              _showChefRankingDialog(context);
            },
            child: Transform.scale(
              scale: 0.8 + (_scaleController.value * 0.2),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8 : 10,
                  vertical: isMobile ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.withValues(alpha: 0.3),
                      Colors.orange.withValues(alpha: 0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Star display
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (index) {
                        return AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final isActive = index < stars;
                            final delay = index * 0.1;
                            final pulseValue =
                                (_pulseController.value + delay) % 1.0;

                            return Transform.scale(
                              scale: isActive ? 1.0 + (pulseValue * 0.1) : 0.7,
                              child: Transform.rotate(
                                angle: isActive ? (pulseValue * 0.1) - 0.05 : 0,
                                child: Icon(
                                  isActive
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color:
                                      isActive
                                          ? Color.lerp(
                                            Colors.amber,
                                            Colors.yellow.shade300,
                                            pulseValue,
                                          )
                                          : Colors.white.withValues(alpha: 0.3),
                                  size: isMobile ? 12 : 14,
                                  shadows:
                                      isActive
                                          ? [
                                            Shadow(
                                              color: Colors.amber.withValues(
                                                alpha: 0.5,
                                              ),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ]
                                          : null,
                                ),
                              ),
                            );
                          },
                        );
                      }),
                    ),
                    SizedBox(height: isMobile ? 2 : 4),
                    // Title
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 9 : 11,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.7),
                            offset: const Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showChefRankingDialog(BuildContext context) {
    final ranking = chefRanking;
    final int stars = ranking['stars'];
    final String title = ranking['title'];
    final String description = ranking['description'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.amber.withValues(alpha: 0.1),
                  Colors.orange.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Star display
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final isActive = index < stars;
                    return Icon(
                      isActive ? Icons.star_rounded : Icons.star_border_rounded,
                      color: isActive ? Colors.amber : Colors.grey.shade300,
                      size: 32,
                    );
                  }),
                ),
                const SizedBox(height: 16),
                // Title
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Description
                Text(
                  description,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Stats breakdown
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ranking Breakdown:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Recipe Difficulty: ${_getAverageDifficultyText()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '• Saved Recipes: $savedRecipesCount',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getNextLevelText(),
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Close button
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Got it!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getAverageDifficultyText() {
    if (recipeDifficulties.isEmpty) return 'No recipes yet';

    final counts = {'easy': 0, 'medium': 0, 'hard': 0};
    for (String difficulty in recipeDifficulties) {
      counts[difficulty.toLowerCase()] =
          (counts[difficulty.toLowerCase()] ?? 0) + 1;
    }

    final most = counts.entries.reduce((a, b) => a.value > b.value ? a : b);
    return 'Mostly ${most.key} recipes';
  }

  String _getNextLevelText() {
    final ranking = chefRanking;
    final int currentStars = ranking['stars'];

    if (currentStars >= 5) {
      return 'You\'ve reached the highest level! 🎉';
    }

    final nextLevel = currentStars + 1;
    String nextTitle;
    switch (nextLevel) {
      case 2:
        nextTitle = 'Home Cook';
        break;
      case 3:
        nextTitle = 'Skilled Chef';
        break;
      case 4:
        nextTitle = 'Expert Chef';
        break;
      case 5:
        nextTitle = 'Master Chef';
        break;
      default:
        nextTitle = 'Next Level';
    }

    if (savedRecipesCount < 50) {
      return 'Save ${50 - savedRecipesCount} more recipes to get closer to $nextTitle!';
    } else if (savedRecipesCount < 100) {
      return 'Save ${100 - savedRecipesCount} more recipes to reach $nextTitle!';
    } else if (savedRecipesCount < 300) {
      return 'Save ${300 - savedRecipesCount} more recipes to reach $nextTitle!';
    } else {
      return 'Try more challenging recipes to reach $nextTitle!';
    }
  }

  Widget _buildNavigationContent(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final isMobile = AppBreakpoints.isMobile(context);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
      child: Column(
        children: [
          SizedBox(height: isMobile ? 8 : 12),
          _buildFloatingNavSection(context, colorScheme, isDark, 'Navigation', [
            _NavItem(Icons.home_rounded, 'Home', '/home', colorScheme.primary, 0),
            _NavItem(
              Icons.restaurant_menu_rounded,
              'My Recipes',
              '/myRecipes',
              colorScheme.warning,
              2,
            ),
            _NavItem(
              Icons.collections_bookmark_rounded,
              'Collections',
              '/collections',
              colorScheme.success,
              3,
            ),
            _NavItem(
              Icons.favorite_rounded,
              'Favorites',
              '/favorites',
              colorScheme.tertiary,
              4,
            ),
          ]),
          SizedBox(height: isMobile ? 12 : 20),
          _buildFloatingNavSection(
            context,
            colorScheme,
            isDark,
            'Recipe Tools',
            [
              _NavItem(
                Icons.explore_rounded,
                'Discover',
                '/discover',
                colorScheme.info,
                7,
              ),
              _NavItem(
                Icons.add_box_rounded,
                'Import Recipe',
                '/import',
                colorScheme.secondary,
                5,
              ),
              _NavItem(
                Icons.auto_awesome_rounded,
                'AI Generate Recipe (Beta)',
                '/generateRecipe',
                colorScheme.onTertiary,
                6,
              ),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 20),
          _buildFloatingNavSection(context, colorScheme, isDark, 'Settings', [
            _NavItem(
              Icons.settings_rounded,
              'Settings',
              '/settings',
              colorScheme.outline,
              8,
            ),
          ]),
          SizedBox(height: isMobile ? 12 : 16),
        ],
      ),
    );
  }

  Widget _buildFloatingNavSection(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
    String title,
    List<_NavItem> items,
  ) {
    final isMobile = AppBreakpoints.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: isMobile ? 16 : 20,
            bottom: isMobile ? 8 : 12,
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: (isDark ? Colors.white : colorScheme.onSurface).withValues(
                alpha: 0.8,
              ),
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors:
                  isDark
                      ? [
                        Colors.white.withValues(alpha: 0.05),
                        Colors.white.withValues(alpha: 0.02),
                      ]
                      : [
                        Colors.white.withValues(alpha: 0.7),
                        Colors.white.withValues(alpha: 0.3),
                      ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Column(
                children:
                    items
                        .map(
                          (item) => _buildFloatingNavItem(
                            context,
                            colorScheme,
                            isDark,
                            item,
                          ),
                        )
                        .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingNavItem(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
    _NavItem item,
  ) {
    final bool isActive = ModalRoute.of(context)?.settings.name == item.route;
    final isMobile = AppBreakpoints.isMobile(context);

    return AnimatedBuilder(
      animation: Listenable.merge([
        _itemSlideAnimations[item.index],
        _itemFadeAnimations[item.index],
      ]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_itemSlideAnimations[item.index].value * 300, 0),
          child: FadeTransition(
            opacity: _itemFadeAnimations[item.index],
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.95, end: 1.0),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    margin: EdgeInsets.symmetric(
                      horizontal: isMobile ? 6 : 8,
                      vertical: isMobile ? 2 : 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
                      gradient:
                          isActive
                              ? LinearGradient(
                                colors: [
                                  item.color.withValues(alpha: 0.3),
                                  item.color.withValues(alpha: 0.1),
                                ],
                              )
                              : null,
                      border:
                          isActive
                              ? Border.all(
                                color: item.color.withValues(alpha: 0.5),
                                width: 1,
                              )
                              : null,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
                        onTap: () {
                          // Add haptic feedback for better UX
                          Navigator.pop(context);
                          if (!isActive) {
                            Navigator.pushNamed(context, item.route);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 16 : 20,
                            vertical: isMobile ? 12 : 16,
                          ),
                          child: Row(
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.8, end: 1.0),
                                duration: Duration(
                                  milliseconds: 400 + (item.index * 50),
                                ),
                                curve: Curves.elasticOut,
                                builder: (context, iconScale, child) {
                                  return Transform.scale(
                                    scale: iconScale,
                                    child: Container(
                                      width: isMobile ? 32 : 40,
                                      height: isMobile ? 32 : 40,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            item.color.withValues(alpha: 0.9),
                                            item.color.withValues(alpha: 0.7),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: item.color.withValues(
                                              alpha: 0.4,
                                            ),
                                            blurRadius: isMobile ? 8 : 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        item.icon,
                                        color: Colors.white,
                                        size: isMobile ? 16 : 20,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(width: isMobile ? 12 : 16),
                              Expanded(
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: Duration(
                                    milliseconds: 500 + (item.index * 60),
                                  ),
                                  curve: Curves.easeOutQuart,
                                  builder: (context, opacity, child) {
                                    return Opacity(
                                      opacity: opacity,
                                      child: Text(
                                        item.title,
                                        style: TextStyle(
                                          fontSize: isMobile ? 14 : 16,
                                          fontWeight:
                                              isActive
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                          color:
                                              isActive
                                                  ? item.color
                                                  : (isDark
                                                          ? Colors.white
                                                          : colorScheme
                                                              .onSurface)
                                                      .withValues(alpha: 0.8),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (isActive)
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.elasticOut,
                                  builder: (context, scale, child) {
                                    return Transform.scale(
                                      scale: scale,
                                      child: Container(
                                        width: isMobile ? 6 : 8,
                                        height: isMobile ? 6 : 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: item.color,
                                          boxShadow: [
                                            BoxShadow(
                                              color: item.color.withValues(
                                                alpha: 0.6,
                                              ),
                                              blurRadius: 6,
                                              offset: const Offset(0, 0),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingFooter(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final isMobile = AppBreakpoints.isMobile(context);

    return AnimatedBuilder(
      animation: _fadeController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeController,
          child: Container(
            margin: EdgeInsets.all(isMobile ? 12 : 16),
            padding: EdgeInsets.symmetric(vertical: isMobile ? 16 : 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
              gradient: LinearGradient(
                colors:
                    isDark
                        ? [
                          Colors.white.withValues(alpha: 0.05),
                          Colors.white.withValues(alpha: 0.02),
                        ]
                        : [
                          Colors.white.withValues(alpha: 0.6),
                          Colors.white.withValues(alpha: 0.3),
                        ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/icons/logo.png',
                      height: isMobile ? 20 : 24,
                      width: isMobile ? 20 : 24,
                    ),
                    SizedBox(width: isMobile ? 6 : 8),
                    Text(
                      'RecipEase',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 4 : 8),
                Text(
                  'v1.0.1 • Made with ❤️',
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 12,
                    color: (isDark ? Colors.white : colorScheme.onSurface)
                        .withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NavItem {
  final IconData icon;
  final String title;
  final String route;
  final Color color;
  final int index;

  const _NavItem(this.icon, this.title, this.route, this.color, this.index);
}
