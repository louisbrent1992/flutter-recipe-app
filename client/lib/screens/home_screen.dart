import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipease/providers/auth_provider.dart';
import 'package:recipease/services/collection_service.dart';
import 'dart:async';
import '../providers/user_profile_provider.dart';
import '../components/custom_app_bar.dart';
import '../components/nav_drawer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/theme.dart';
import '../providers/recipe_provider.dart';
import '../models/recipe.dart';
import '../models/recipe_collection.dart';
import '../components/dynamic_banner.dart';
import '../providers/dynamic_ui_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Lightweight model representing a quick-access category on the home screen.
class _CategoryItem {
  final String title;
  final IconData icon;
  final String route;
  final Color color;

  const _CategoryItem(this.title, this.icon, this.route, this.color);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  final String username =
      FirebaseAuth.instance.currentUser?.displayName ?? 'User';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  // Fallback hero image URL (used if dynamic UI doesn't provide one)
  static const String _defaultHeroImageUrl =
      'https://res.cloudinary.com/client-images/image/upload/v1763258640/Recipe%20App/Gemini_Generated_Image_1isjyd1isjyd1isj_jv1rvc.png';
  bool _isBooting = true;
  StreamSubscription<void>? _recipesChangedSubscription;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.forward();

    // Preload user and random recipes for carousels
    Future.microtask(() {
      if (mounted) {
        final recipeProvider = Provider.of<RecipeProvider>(
          context,
          listen: false,
        );

        // Load first batch of user's own recipes
        recipeProvider.loadUserRecipes(limit: 20);

        // Fetch a larger set of random recipes for discovery to ensure we have enough after filtering
        recipeProvider.searchExternalRecipes(
          query: '',
          limit: 50,
          random: true,
        );

        // Ensure first frame shows placeholders even before provider flips loading
        if (mounted) setState(() => _isBooting = false);
      }
    });

    // Listen for cross-screen recipe updates to refresh all sections
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final recipeProvider = Provider.of<RecipeProvider>(
        context,
        listen: false,
      );
      _recipesChangedSubscription = recipeProvider.onRecipesChanged.listen((_) {
        if (mounted) {
          _refreshAllSections(context);
        }
      });
    });
  }

  // Refresh all home sections at once
  void _refreshAllSections(BuildContext context) {
    final recipeProvider = context.read<RecipeProvider>();
    final collectionService = context.read<CollectionService>();

    // Trigger parallel refreshes (no await needed for button callbacks)
    recipeProvider.loadUserRecipes(limit: 20, forceRefresh: true);
    recipeProvider.searchExternalRecipes(
      query: '',
      limit: 50,
      forceRefresh: true,
      random: true,
    );
    collectionService.getCollections(forceRefresh: true);

    // Ensure widgets depending on FutureBuilder rebuild
    setState(() {});
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    _recipesChangedSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Access the user data from the provider
    Provider.of<CollectionService>(context, listen: false);

    // Check if userData is null and navigate to login if necessary
    if (context.read<AuthService>().user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
      return Container(); // Return an empty container while redirecting
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: CustomAppBar(
        title: 'RecipEase',
        useLogo: true,
        leading: _buildModernMenuButton(context),
      ),
      drawer: const NavDrawer(),
      body: Stack(
        children: [
          SafeArea(
            child: Consumer<UserProfileProvider>(
              builder: (context, profile, _) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  child: Scrollbar(
                    controller: _scrollController,
                    child: ListView(
                      controller: _scrollController,
                      padding: EdgeInsets.only(
                        left: AppSpacing.responsive(context),
                        right: AppSpacing.responsive(context),
                        top: AppSpacing.responsive(context),
                        bottom:
                            AppSpacing.responsive(context) +
                            80, // Extra space for floating bar
                      ),
                      children: [
                        // Dynamic UI banners (home_top)
                        Consumer<DynamicUiProvider>(
                          builder: (context, dyn, _) {
                            final banners = dyn.bannersForPlacement('home_top');
                            if (banners.isEmpty) return const SizedBox.shrink();
                            return Column(
                              children:
                                  banners
                                      .map((b) => DynamicBanner(banner: b))
                                      .toList(),
                            );
                          },
                        ),
                        _buildHeroSection(context),
                        // --- Your Recipes carousel ---
                        Consumer<DynamicUiProvider>(
                          builder: (context, dynamicUi, _) {
                            if (!(dynamicUi.config?.isSectionVisible(
                                  'yourRecipesCarousel',
                                ) ??
                                true)) {
                              return const SizedBox.shrink();
                            }
                            return Consumer<RecipeProvider>(
                              builder: (context, recipeProvider, _) {
                                final saved = recipeProvider.userRecipes;
                                if ((recipeProvider.isLoading || _isBooting) &&
                                    saved.isEmpty) {
                                  return _buildSectionLoading(
                                    context,
                                    title: 'Your Recipes',
                                    height: 180,
                                  );
                                }
                                if (saved.isEmpty &&
                                    recipeProvider.error != null) {
                                  return _buildSectionMessage(
                                    context,
                                    title: 'Your Recipes',
                                    message:
                                        recipeProvider
                                            .error!
                                            .userFriendlyMessage,
                                    onRetry: () {
                                      _refreshAllSections(context);
                                    },
                                  );
                                }
                                if (saved.isEmpty) return const SizedBox();
                                return _buildRecipeCarousel(
                                  context,
                                  title: 'Your Recipes',
                                  recipes: saved.take(10).toList(),
                                );
                              },
                            );
                          },
                        ),
                        SizedBox(height: AppSpacing.responsive(context)),
                        // --- Discover & Try carousel ---
                        Consumer<DynamicUiProvider>(
                          builder: (context, dynamicUi, _) {
                            if (!(dynamicUi.config?.isSectionVisible(
                                  'discoverCarousel',
                                ) ??
                                true)) {
                              return const SizedBox.shrink();
                            }
                            return Consumer<RecipeProvider>(
                              builder: (context, recipeProvider, _) {
                                final random =
                                    recipeProvider.generatedRecipes
                                        .where(
                                          (r) =>
                                              !recipeProvider.userRecipes.any(
                                                (u) => u.id == r.id,
                                              ),
                                        )
                                        .take(10)
                                        .toList();
                                if ((recipeProvider.isLoading || _isBooting) &&
                                    random.isEmpty) {
                                  return _buildSectionLoading(
                                    context,
                                    title: 'Discover & Try',
                                    height: 180,
                                  );
                                }
                                if (random.isEmpty &&
                                    recipeProvider.error != null) {
                                  return _buildSectionMessage(
                                    context,
                                    title: 'Discover & Try',
                                    message:
                                        recipeProvider
                                            .error!
                                            .userFriendlyMessage,
                                    onRetry: () {
                                      _refreshAllSections(context);
                                    },
                                  );
                                }
                                if (random.isEmpty) return const SizedBox();
                                return _buildRecipeCarousel(
                                  context,
                                  title: 'Discover & Try',
                                  recipes: random,
                                );
                              },
                            );
                          },
                        ),
                        SizedBox(height: AppSpacing.responsive(context)),
                        // --- Collections carousel ---
                        Consumer<DynamicUiProvider>(
                          builder: (context, dynamicUi, _) {
                            if (!(dynamicUi.config?.isSectionVisible(
                                  'collectionsCarousel',
                                ) ??
                                true)) {
                              return const SizedBox.shrink();
                            }
                            return Consumer<CollectionService>(
                              builder: (context, collectionProvider, _) {
                                final collections = collectionProvider
                                    .getCollections(
                                      updateSpecialCollections: true,
                                    )
                                    .then((value) => value.take(10).toList());
                                return _buildCollectionCarousel(
                                  context,
                                  title: 'Collections',
                                  collections: collections,
                                );
                              },
                            );
                          },
                        ),
                        SizedBox(height: AppSpacing.responsive(context)),
                        // Category scroller with features
                        Consumer<DynamicUiProvider>(
                          builder: (context, dynamicUi, _) {
                            if (!(dynamicUi.config?.isSectionVisible(
                                  'featuresSection',
                                ) ??
                                true)) {
                              return const SizedBox.shrink();
                            }
                            return _buildCategoryScroller(
                              context,
                              title: 'Features',
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the top hero banner with an enticing recipe photo and overlay text.
  Widget _buildHeroSection(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        top: AppSpacing.responsive(context),
        bottom: AppSpacing.responsive(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          alignment: Alignment.bottomLeft,
          children: [
            // Background image
            AspectRatio(
              aspectRatio: 3 / 2,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final devicePixelRatio =
                      MediaQuery.of(context).devicePixelRatio;

                  return Consumer<DynamicUiProvider>(
                    builder: (context, dynamicUi, _) {
                      // Get hero image from dynamic UI config, fallback to default
                      final heroImageUrl =
                          dynamicUi.config?.heroImageUrl ??
                          _defaultHeroImageUrl;

                      return Image.network(
                        heroImageUrl,
                        fit: BoxFit.fitWidth,
                        cacheWidth:
                            (constraints.maxWidth * devicePixelRatio).round(),
                        cacheHeight:
                            (constraints.maxHeight * devicePixelRatio).round(),
                        filterQuality: FilterQuality.high,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomLeft,
                                end: Alignment.topRight,
                                colors: [
                                  Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(
                                    alpha:
                                        Theme.of(
                                          context,
                                        ).colorScheme.alphaMedium,
                                  ),
                                  Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(
                                    alpha:
                                        Theme.of(context).colorScheme.alphaHigh,
                                  ),
                                  Theme.of(context).colorScheme.primary,
                                ],
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Failed to load image',
                                    style: TextStyle(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Please check the image file',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary.withValues(
                                        alpha:
                                            Theme.of(
                                              context,
                                            ).colorScheme.alphaHigh,
                                      ),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            // Gradient overlay - reduced opacity for clearer background image
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Theme.of(context).colorScheme.surface.withValues(
                        alpha: Theme.of(context).colorScheme.alphaMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Text overlay
            Padding(
              padding: AppSpacing.allResponsive(context),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.responsive(context) * 0.75,
                  vertical: AppSpacing.responsive(context) * 0.5,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(
                    alpha: Theme.of(context).colorScheme.alphaHigh,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Consumer<DynamicUiProvider>(
                  builder: (context, dynamicUi, _) {
                    final config = dynamicUi.config;
                    // Get dynamic welcome message or use default
                    final welcomeText =
                        config?.formatWelcomeMessage(username) ?? 'Welcome,';
                    // Split welcome text to handle username placement
                    final welcomeParts = welcomeText.split('{username}');
                    final hasUsernamePlaceholder = welcomeText.contains(
                      '{username}',
                    );

                    // Get dynamic subtitle or use default
                    final subtitle =
                        config?.heroSubtitle ??
                        'What would you like to cook today?';

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome message - handle {username} placeholder
                        if (hasUsernamePlaceholder && welcomeParts.length == 2)
                          RichText(
                            text: TextSpan(
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                shadows: [
                                  Shadow(
                                    offset: const Offset(0, 1),
                                    blurRadius: 2,
                                    color: Colors.black.withValues(alpha: 0.3),
                                  ),
                                ],
                              ),
                              children: [
                                TextSpan(text: welcomeParts[0]),
                                TextSpan(
                                  text: username,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                TextSpan(text: welcomeParts[1]),
                              ],
                            ),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                welcomeText,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  shadows: [
                                    Shadow(
                                      offset: const Offset(0, 1),
                                      blurRadius: 2,
                                      color: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!welcomeText.contains(username))
                                Text(
                                  username,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    shadows: [
                                      Shadow(
                                        offset: const Offset(0, 1),
                                        blurRadius: 2,
                                        color: Colors.black.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            shadows: [
                              Shadow(
                                offset: const Offset(0, 1),
                                blurRadius: 2,
                                color: Colors.black.withValues(alpha: 0.2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Horizontal list of quick-access category cards.
  Widget _buildCategoryScroller(BuildContext context, {required String title}) {
    final categories = _quickCategories();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(AppSpacing.sm),

          child: GestureDetector(
            onTap: () {
              // Navigate based on the title
              if (title.contains('Your Recipes')) {
                Navigator.pushNamed(context, '/myRecipes');
              } else {
                Navigator.pushNamed(context, '/discover');
              }
            },
            child: Row(
              children: [
                if (title.contains('Features')) ...[
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 24,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: AppTypography.responsiveFontSize(
                        context,
                        mobile: 20,
                        tablet: 22,
                        desktop: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height:
              AppBreakpoints.isDesktop(context)
                  ? 160
                  : AppBreakpoints.isTablet(context)
                  ? 140
                  : 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder:
                (_, __) => SizedBox(
                  width: AppSpacing.responsive(
                    context,
                    mobile: 12,
                    tablet: 16,
                    desktop: 20,
                  ),
                ),
            itemBuilder: (context, index) {
              final cat = categories[index];
              return _buildCategoryCard(context, cat);
            },
          ),
        ),
      ],
    );
  }

  /// Builds a single category card.
  Widget _buildCategoryCard(BuildContext context, _CategoryItem cat) {
    final theme = Theme.of(context);
    final cardHeight =
        AppBreakpoints.isDesktop(context)
            ? 140.0
            : AppBreakpoints.isTablet(context)
            ? 120.0
            : 100.0;
    final cardWidth =
        AppBreakpoints.isDesktop(context)
            ? 300.0
            : AppBreakpoints.isTablet(context)
            ? 250.0
            : 200.0;
    final borderRadius = AppBreakpoints.isDesktop(context) ? 20.0 : 16.0;

    return SizedBox(
      height: cardHeight,
      width: cardWidth,
      child: Card(
        color: Theme.of(context).colorScheme.surface.withValues(
          alpha: Theme.of(context).colorScheme.alphaVeryHigh,
        ),
        elevation: AppBreakpoints.isDesktop(context) ? 3 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, cat.route),
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppBreakpoints.isDesktop(context) ? 20 : 16,
              vertical: AppBreakpoints.isDesktop(context) ? 16 : 12,
            ),
            child: Row(
              children: [
                Container(
                  width: AppBreakpoints.isDesktop(context) ? 56 : 40,
                  height: AppBreakpoints.isDesktop(context) ? 56 : 40,
                  decoration: BoxDecoration(
                    color: cat.color.withValues(
                      alpha: Theme.of(context).colorScheme.overlayMedium,
                    ),
                    borderRadius: BorderRadius.circular(
                      AppBreakpoints.isDesktop(context) ? 16 : 12,
                    ),
                  ),
                  child: Icon(
                    cat.icon,
                    color: cat.color,
                    size: AppBreakpoints.isDesktop(context) ? 28 : 20,
                  ),
                ),
                SizedBox(width: AppBreakpoints.isDesktop(context) ? 16 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        cat.title,
                        style:
                            AppBreakpoints.isDesktop(context)
                                ? theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                )
                                : theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(
                        height: AppBreakpoints.isDesktop(context) ? 6 : 4,
                      ),
                      Text(
                        _getCategoryDescription(cat.title),
                        style:
                            AppBreakpoints.isDesktop(context)
                                ? theme.textTheme.bodyMedium?.copyWith(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                  height: 1.3,
                                )
                                : theme.textTheme.bodySmall?.copyWith(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                  height: 1.3,
                                ),
                        maxLines: AppBreakpoints.isDesktop(context) ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Helper to define quick categories with consistent data.
  List<_CategoryItem> _quickCategories() {
    return [
      _CategoryItem(
        'Import Recipe',
        Icons.ios_share_rounded,
        '/import',
        Theme.of(context).colorScheme.success,
      ),
      _CategoryItem(
        'Generate Recipes',
        Icons.auto_awesome,
        '/generate',
        Colors.purple,
      ),
      _CategoryItem(
        'My Recipes',
        Icons.restaurant_menu_rounded,
        '/myRecipes',
        Theme.of(context).colorScheme.warning,
      ),
      _CategoryItem(
        'My Collections',
        Icons.collections_bookmark_rounded,
        '/collections',
        Colors.purple,
      ),
      _CategoryItem(
        'Discover Recipes',
        Icons.explore,
        '/discover',
        Theme.of(context).colorScheme.info,
      ),
    ];
  }

  /// Helper to get category descriptions for the cards.
  String _getCategoryDescription(String title) {
    switch (title) {
      case 'My Recipes':
        return 'Your personal recipe collection and cooking creations';
      case 'My Collections':
        return 'Organized recipe lists for meal planning and themes';
      case 'Discover Recipes':
        return 'Explore trending recipes and new cooking inspiration';

      case 'Import Recipe':
        return 'Add recipes from websites, blogs, and social media';
      case 'Generate Recipes':
        return 'Create custom recipes tailored to you';
      default:
        return 'Quick access to cooking features';
    }
  }

  /// Builds a recipe carousel section with a horizontal list of recipe cards.
  Widget _buildRecipeCarousel(
    BuildContext context, {
    required String title,
    required List<Recipe> recipes,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: GestureDetector(
            onTap: () {
              // Navigate based on the title
              if (title.contains('Your Recipes')) {
                Navigator.pushNamed(context, '/myRecipes');
              } else if (title.contains('Discover')) {
                Navigator.pushNamed(context, '/discover');
              } else {
                // Default to my recipes for other cases
                Navigator.pushNamed(context, '/myRecipes');
              }
            },
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: AppTypography.responsiveFontSize(
                        context,
                        mobile: 20,
                        tablet: 22,
                        desktop: 24,
                      ),
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recipes.length,
            separatorBuilder: (_, __) => SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              return _buildRecipeCard(context, recipe);
            },
          ),
        ),
      ],
    );
  }

  /// Builds an individual recipe card used within carousels.
  Widget _buildRecipeCard(BuildContext context, Recipe recipe) {
    final theme = Theme.of(context);
    final cardWidth =
        AppBreakpoints.isDesktop(context)
            ? 220.0
            : AppBreakpoints.isTablet(context)
            ? 180.0
            : 140.0;
    return GestureDetector(
      onLongPressStart: (details) {
        _showRecipeContextMenu(context, recipe, details.globalPosition);
      },
      child: InkWell(
        onTap:
            () =>
                Navigator.pushNamed(context, '/recipeDetail', arguments: recipe),
        child: Container(
        width: cardWidth,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            AppBreakpoints.isDesktop(context) ? 16 : 12,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: AppBreakpoints.isDesktop(context) ? 6 : 4,
              offset: Offset(0, AppBreakpoints.isDesktop(context) ? 3 : 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            AppBreakpoints.isDesktop(context) ? 16 : 12,
          ),
          child: Stack(
            children: [
              // Image
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final devicePixelRatio =
                        MediaQuery.of(context).devicePixelRatio;
                    return Image.network(
                      recipe.imageUrl,
                      fit: BoxFit.cover,
                      cacheWidth:
                          (constraints.maxWidth * devicePixelRatio).round(),
                      cacheHeight:
                          (constraints.maxHeight * devicePixelRatio).round(),
                      filterQuality: FilterQuality.high,
                      errorBuilder:
                          (_, __, ___) => Container(
                            color: Theme.of(
                              context,
                            ).colorScheme.secondary.withValues(
                              alpha:
                                  Theme.of(context).colorScheme.overlayMedium,
                            ),
                            child: Icon(
                              Icons.restaurant,
                              size: AppSizing.responsiveIconSize(
                                context,
                                mobile: 40,
                                tablet: 48,
                                desktop: 56,
                              ),
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                    );
                  },
                ),
              ),
              // Gradient overlay bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: AppBreakpoints.isDesktop(context) ? 80 : 60,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.54),
                      ],
                    ),
                  ),
                ),
              ),
              // Title
              Positioned(
                left: AppBreakpoints.isDesktop(context) ? 12 : 8,
                right: AppBreakpoints.isDesktop(context) ? 12 : 8,
                bottom: AppBreakpoints.isDesktop(context) ? 12 : 8,
                child: Text(
                  recipe.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      AppBreakpoints.isDesktop(context)
                          ? theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          )
                          : theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  /// Show context menu for recipe actions
  void _showRecipeContextMenu(
    BuildContext context,
    Recipe recipe,
    Offset position,
  ) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              Icon(
                Icons.visibility_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              const Text('View Details'),
            ],
          ),
          onTap: () {
            Future.delayed(const Duration(milliseconds: 100), () {
              Navigator.pushNamed(
                context,
                '/recipeDetail',
                arguments: recipe,
              );
            });
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(
                Icons.share_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              const Text('Share Recipe'),
            ],
          ),
          onTap: () {
            Future.delayed(const Duration(milliseconds: 100), () {
              // Share recipe functionality
              final String shareText = '''
${recipe.title}

Description:
${recipe.description}

Cooking Time: ${recipe.cookingTime} minutes
Servings: ${recipe.servings}
Difficulty: ${recipe.difficulty}

Ingredients:
${recipe.ingredients.map((i) => '• $i').join('\n')}

Instructions:
${recipe.instructions.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}

${recipe.tags.isNotEmpty ? 'Tags: ${recipe.tags.join(', ')}' : ''}

Shared from Recipe App
''';
              Share.share(shareText);
            });
          },
        ),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  /// Builds a collection carousel section with a horizontal list of collection cards.
  Widget _buildCollectionCarousel(
    BuildContext context, {
    required String title,
    required Future<List<RecipeCollection>> collections,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/collections'),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: AppTypography.responsiveFontSize(
                        context,
                        mobile: 20,
                        tablet: 22,
                        desktop: 24,
                      ),
                      color: Theme.of(context).colorScheme.onSurface,
                      decorationColor: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 220,
          child: FutureBuilder<List<RecipeCollection>>(
            future: collections,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildSectionLoading(
                  context,
                  title: title,
                  height: 220,
                  includeTitle: false,
                );
              }
              if (snapshot.hasError) {
                return _buildSectionMessage(
                  context,
                  title: title,
                  message:
                      'Unable to load collections right now. Please try again.',
                  onRetry: () {
                    _refreshAllSections(context);
                  },
                  includeTitle: false,
                  leadingIcon: null,
                  height: 220,
                );
              }
              if (!snapshot.hasData) {
                return _buildSectionMessage(
                  context,
                  title: title,
                  message:
                      'No collections yet. Add your first recipe to see it here.',
                  onRetry: () {
                    _refreshAllSections(context);
                  },
                  includeTitle: false,
                  leadingIcon: null,
                  secondaryActionLabel: 'Add a Recipe',
                  secondaryAction: () {
                    Navigator.pushNamed(context, '/import');
                  },
                  height: 220,
                );
              }
              final collections = snapshot.data!;
              if (collections.isEmpty) {
                return _buildSectionMessage(
                  context,
                  title: title,
                  message:
                      'No collections yet. Add your first recipe to see it here.',
                  onRetry: null,
                  includeTitle: false,
                  leadingIcon: null,
                  secondaryActionLabel: 'Add a Recipe',
                  secondaryAction: () {
                    Navigator.pushNamed(context, '/import');
                  },
                  height: 220,
                );
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: collections.length,
                separatorBuilder: (_, __) => SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final collection = collections[index];
                  return _buildCollectionCard(context, collection);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Builds a standardized loading placeholder for a section with a title
  Widget _buildSectionLoading(
    BuildContext context, {
    required String title,
    double height = 180,
    bool includeTitle = true,
  }) {
    final theme = Theme.of(context);

    void navigate() {
      if (title.contains('Your Recipes')) {
        Navigator.pushNamed(context, '/myRecipes');
      } else if (title.contains('Discover')) {
        Navigator.pushNamed(context, '/discover');
      } else if (title.contains('Collections')) {
        Navigator.pushNamed(context, '/collections');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (includeTitle)
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: GestureDetector(
              onTap: navigate,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: AppTypography.responsiveFontSize(
                          context,
                          mobile: 18,
                          tablet: 20,
                          desktop: 22,
                        ),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ],
              ),
            ),
          ),
        SizedBox(
          height: height,
          child: Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds a standardized message placeholder for a section with retry
  Widget _buildSectionMessage(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onRetry,
    double height = 180,
    bool includeTitle = true,
    IconData? leadingIcon = Icons.wifi_off_rounded,
    String? secondaryActionLabel,
    VoidCallback? secondaryAction,
  }) {
    final theme = Theme.of(context);

    void navigate() {
      if (title.contains('Your Recipes')) {
        Navigator.pushNamed(context, '/myRecipes');
      } else if (title.contains('Discover')) {
        Navigator.pushNamed(context, '/discover');
      } else if (title.contains('Collections')) {
        Navigator.pushNamed(context, '/collections');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (includeTitle)
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: GestureDetector(
              onTap: navigate,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: AppTypography.responsiveFontSize(
                          context,
                          mobile: 18,
                          tablet: 20,
                          desktop: 22,
                        ),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.refresh,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ],
              ),
            ),
          ),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(
              alpha: Theme.of(context).colorScheme.alphaHigh,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(
                alpha: Theme.of(context).colorScheme.overlayLight,
              ),
              width: 1,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leadingIcon != null)
                  Icon(
                    leadingIcon,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    message.isNotEmpty
                        ? message
                        : 'Unable to load right now. Please try again.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (onRetry != null)
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                if (secondaryAction != null && secondaryActionLabel != null)
                  TextButton(
                    onPressed: secondaryAction,
                    child: Text(secondaryActionLabel),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Builds an individual collection card used within the collection carousel.
  Widget _buildCollectionCard(
    BuildContext context,
    RecipeCollection collection,
  ) {
    final theme = Theme.of(context);
    final hasRecipes = collection.recipes.isNotEmpty;
    final recipesWithImages =
        collection.recipes.where((r) => r.imageUrl.isNotEmpty).toList();

    final collectionCardWidth =
        AppBreakpoints.isDesktop(context)
            ? 260.0
            : AppBreakpoints.isTablet(context)
            ? 220.0
            : 180.0;
    final borderRadius = AppBreakpoints.isDesktop(context) ? 24.0 : 20.0;

    return SizedBox(
      width: collectionCardWidth,
      child: Card(
        elevation: AppBreakpoints.isDesktop(context) ? 6 : 4,
        shadowColor: collection.color.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: InkWell(
          onTap:
              () => Navigator.pushNamed(
                context,
                '/collectionDetail',
                arguments: collection,
              ),
          borderRadius: BorderRadius.circular(borderRadius),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Stack(
              children: [
                // Background with recipe images or gradient
                Positioned.fill(
                  child:
                      hasRecipes && recipesWithImages.isNotEmpty
                          ? _buildRecipeImagesBackground(
                            recipesWithImages,
                            collection.color,
                          )
                          : _buildGradientBackground(collection.color),
                ),

                // Gradient overlay for text readability
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                ),

                // Collection icon (top-right corner)
                Positioned(
                  top: AppBreakpoints.isDesktop(context) ? 16 : 12,
                  right: AppBreakpoints.isDesktop(context) ? 16 : 12,
                  child: Container(
                    padding: EdgeInsets.all(
                      AppBreakpoints.isDesktop(context) ? 12 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface.withValues(
                        alpha: Theme.of(context).colorScheme.alphaVeryHigh,
                      ),
                      borderRadius: BorderRadius.circular(
                        AppBreakpoints.isDesktop(context) ? 16 : 12,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: AppBreakpoints.isDesktop(context) ? 6 : 4,
                          offset: Offset(
                            0,
                            AppBreakpoints.isDesktop(context) ? 3 : 2,
                          ),
                        ),
                      ],
                    ),
                    child: Icon(
                      collection.icon,
                      size: AppBreakpoints.isDesktop(context) ? 28 : 20,
                      color: collection.color,
                    ),
                  ),
                ),

                // Collection info (bottom)
                Positioned(
                  left: AppBreakpoints.isDesktop(context) ? 20 : 16,
                  right: AppBreakpoints.isDesktop(context) ? 20 : 16,
                  bottom: AppBreakpoints.isDesktop(context) ? 20 : 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Collection name
                      Text(
                        collection.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AppBreakpoints.isDesktop(context)
                                ? theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.5,
                                      ),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                )
                                : theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.5,
                                      ),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                      ),
                      SizedBox(
                        height: AppBreakpoints.isDesktop(context) ? 6 : 4,
                      ),
                      // Recipe count with icon
                      Row(
                        children: [
                          Icon(
                            Icons.restaurant_menu_rounded,
                            size: AppBreakpoints.isDesktop(context) ? 18 : 14,
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          ),
                          SizedBox(
                            width: AppBreakpoints.isDesktop(context) ? 6 : 4,
                          ),
                          Text(
                            '${collection.recipes.length} ${collection.recipes.length == 1 ? 'recipe' : 'recipes'}',
                            style:
                                AppBreakpoints.isDesktop(context)
                                    ? theme.textTheme.bodyMedium?.copyWith(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest,
                                      fontWeight: FontWeight.w500,
                                    )
                                    : theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest,
                                      fontWeight: FontWeight.w500,
                                    ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a background with recipe images in a grid/collage style
  Widget _buildRecipeImagesBackground(
    List<Recipe> recipes,
    Color fallbackColor,
  ) {
    final imagesToShow = recipes.take(4).toList(); // Show up to 4 images

    if (imagesToShow.length == 1) {
      // Single image fills the entire background
      return Image.network(
        imagesToShow[0].imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildGradientBackground(fallbackColor),
      );
    } else if (imagesToShow.length == 2) {
      // Two images side by side
      return Row(
        children:
            imagesToShow
                .map(
                  (recipe) => Expanded(
                    child: Image.network(
                      recipe.imageUrl,
                      fit: BoxFit.cover,
                      height: double.infinity,
                      errorBuilder:
                          (_, __, ___) => Container(
                            color: fallbackColor.withValues(alpha: 0.3),
                          ),
                    ),
                  ),
                )
                .toList(),
      );
    } else if (imagesToShow.length >= 3) {
      // Grid layout for 3+ images
      return Column(
        children: [
          // Top row - single large image
          Expanded(
            flex: 2,
            child: Image.network(
              imagesToShow[0].imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder:
                  (_, __, ___) =>
                      Container(color: fallbackColor.withValues(alpha: 0.3)),
            ),
          ),
          // Bottom row - smaller images
          Expanded(
            flex: 1,
            child: Row(
              children:
                  imagesToShow
                      .skip(1)
                      .take(2)
                      .map(
                        (recipe) => Expanded(
                          child: Image.network(
                            recipe.imageUrl,
                            fit: BoxFit.cover,
                            height: double.infinity,
                            errorBuilder:
                                (_, __, ___) => Container(
                                  color: fallbackColor.withValues(alpha: 0.3),
                                ),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
        ],
      );
    }

    return _buildGradientBackground(fallbackColor);
  }

  /// Builds a gradient background when no images are available
  Widget _buildGradientBackground(Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.3),
            color.withValues(alpha: 0.7),
            color,
          ],
        ),
      ),
    );
  }

  /// Builds a modern, theme-aligned menu button with refined styling.
  Widget _buildModernMenuButton(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(
        AppSpacing.responsive(context, mobile: 8, tablet: 12, desktop: 16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _scaffoldKey.currentState?.openDrawer(),
          child: Container(
            width: AppSizing.responsiveIconSize(
              context,
              mobile: 36,
              tablet: 40,
              desktop: 44,
            ),
            height: AppSizing.responsiveIconSize(
              context,
              mobile: 36,
              tablet: 40,
              desktop: 44,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Theme.of(context).colorScheme.surface.withValues(
                alpha: Theme.of(context).colorScheme.alphaHigh,
              ),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(
                  alpha: Theme.of(context).colorScheme.overlayLight,
                ),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow.withValues(
                    alpha: Theme.of(context).colorScheme.shadowLight,
                  ),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.menu_rounded,
                color: Theme.of(context).colorScheme.onSurface,
                size: AppSizing.responsiveIconSize(
                  context,
                  mobile: 18,
                  tablet: 20,
                  desktop: 22,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
