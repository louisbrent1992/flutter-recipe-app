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
import 'package:showcaseview/showcaseview.dart';
import '../components/app_tutorial.dart';
import '../services/tutorial_service.dart';
import '../components/inline_banner_ad.dart';
import '../utils/image_utils.dart';
import '../components/offline_banner.dart';

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
  // Local hero image asset for faster loading
  static const String _localHeroImageAsset = 'assets/images/home_hero.png';
  bool _isBooting = true;
  StreamSubscription<void>? _recipesChangedSubscription;
  Future<List<RecipeCollection>>?
  _collectionsFuture; // Cache collections future

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
        final collectionService = Provider.of<CollectionService>(
          context,
          listen: false,
        );

        // Load first batch of user's own recipes (only once)
        recipeProvider.loadUserRecipes(limit: 20);

        // Fetch collections once and cache the future
        _collectionsFuture = collectionService.getCollections(
          updateSpecialCollections: true,
        );

        // Fetch session cache for discovery (500 recipes, used everywhere)
        recipeProvider.fetchSessionDiscoverCache().then((_) {
          // After cache loads, get first 50 for home screen carousel
          final discover = recipeProvider.getFilteredDiscoverRecipes(
            page: 1,
            limit: 50,
          );
          recipeProvider.setGeneratedRecipesFromCache(discover);
        });

        // Fetch community recipes for carousel
        recipeProvider.fetchSessionCommunityCache();

        // Ensure first frame shows placeholders even before provider flips loading
        if (mounted) setState(() => _isBooting = false);
      }
    });

    // Listen for cross-screen recipe updates to trigger UI rebuild
    // Note: Provider already updates data optimistically, no need for network fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final recipeProvider = Provider.of<RecipeProvider>(
        context,
        listen: false,
      );
      _recipesChangedSubscription = recipeProvider.onRecipesChanged.listen((_) {
        if (mounted) {
          // Just trigger rebuild - provider already has updated data
          setState(() {});
        }
      });
    });

    // Check if tutorial should be shown and start it
    // Skip auto-start if this is a manual restart (to prevent double-start)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final tutorialService = TutorialService();

      // Don't auto-start if this is a manual restart
      if (tutorialService.isManualRestart) {
        tutorialService.clearManualRestartFlag();
        return;
      }

      final shouldShow = await tutorialService.shouldShowTutorial();
      if (shouldShow && mounted) {
        // Wait longer for recipes to load before starting tutorial
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          _startTutorial();
        }
      }
    });
  }

  void _startTutorial() {
    try {
      // Start with home hero section (welcome message)
      final List<GlobalKey> tutorialTargets = [
        TutorialKeys.homeHero,
      ];

      // Then navigation drawer menu and credit balance
      tutorialTargets.addAll([
        TutorialKeys.navDrawerMenu,
        TutorialKeys.creditBalance,
      ]);

      // Always include "Your Recipes" - TutorialShowcase is always rendered at parent level
      tutorialTargets.add(TutorialKeys.homeYourRecipes);

      // Always include "Community" - TutorialShowcase is always rendered at parent level
      tutorialTargets.add(TutorialKeys.homeCommunity);

      // Always include "Discover" section
      tutorialTargets.add(TutorialKeys.homeDiscover);

      // Collections are always shown (even if empty state), so safe to include
      tutorialTargets.add(TutorialKeys.homeCollections);

      // Add Features section
      tutorialTargets.add(TutorialKeys.homeFeatures);

      // Add bottom navigation targets
      tutorialTargets.addAll([
        TutorialKeys.bottomNavHome,
        TutorialKeys.bottomNavDiscover,
        TutorialKeys.bottomNavMyRecipes,
        TutorialKeys.bottomNavGenerate,
        TutorialKeys.bottomNavSettings,
      ]);

      ShowcaseView.get().startShowCase(tutorialTargets);
    } catch (e) {
      debugPrint('Error starting tutorial: $e');
    }
  }

  // Refresh only user data (recipes and collections)
  void _refreshUserData(BuildContext context) {
    final recipeProvider = context.read<RecipeProvider>();
    final collectionService = context.read<CollectionService>();

    // Trigger parallel refreshes (no await needed for button callbacks)
    recipeProvider.loadUserRecipes(limit: 20, forceRefresh: true);
    
    // Update cached collections future
    _collectionsFuture = collectionService.getCollections(forceRefresh: true);

    // Ensure widgets depending on FutureBuilder rebuild
    if (mounted) setState(() {});
  }

  // Refresh all home sections at once
  void _refreshAllSections(BuildContext context) {
    final recipeProvider = context.read<RecipeProvider>();
    
    // Refresh user data
    _refreshUserData(context);
    
    // Refresh discover recipes (random) - only on manual refresh
    recipeProvider.searchExternalRecipes(
      query: '',
      limit: 50,
      forceRefresh: true,
      random: true,
    );
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
          // Show offline banner at top when offline
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: OfflineBanner(),
          ),
          SafeArea(
            child: Consumer<UserProfileProvider>(
              builder: (context, profile, _) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: () {
                          final width = MediaQuery.of(context).size.width;
                          // iPad 13 inch is ~1024px, so handle tablets and small desktops similarly
                          if (AppBreakpoints.isTablet(context) ||
                              (AppBreakpoints.isDesktop(context) &&
                                  width < 1400)) {
                            return 1000.0; // Natural max width for iPad and small desktops
                          }
                          if (AppBreakpoints.isDesktop(context)) {
                            return 1200.0; // Larger desktop max width
                          }
                          return double.infinity; // Mobile: full width
                        }(),
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
                                30, // Extra space for floating bar
                          ),
                          children: [
                            // Inline banner ad between app bar and seasonal banner
                            const InlineBannerAd(),

                            // Dynamic UI banners (home_top)
                            Consumer<DynamicUiProvider>(
                              builder: (context, dyn, _) {
                                final banners = dyn.bannersForPlacement(
                                  'home_top',
                                );
                                if (banners.isEmpty) {
                                  return const SizedBox.shrink();
                                }
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
                            // Wrap with TutorialShowcase at this level so GlobalKey is always attached
                            TutorialShowcase(
                              showcaseKey: TutorialKeys.homeYourRecipes,
                              title: 'Your Digital Cookbook 📚',
                              description: 'All your saved, created, and imported recipes in one place. Available offline!',
                              child: Consumer<DynamicUiProvider>(
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
                                      // Show loading if still booting or loading
                                      if (_isBooting || recipeProvider.isLoading) {
                                        return _buildSectionLoading(
                                          context,
                                          title: 'Your Recipes',
                                          height: 180,
                                        );
                                      }
                                      // Show error if failed to load
                                      if (saved.isEmpty &&
                                          recipeProvider.error != null) {
                                        final isOffline = recipeProvider.error!.isNetworkError;
                                        return _buildSectionMessage(
                                          context,
                                          title: 'Your Recipes',
                                          message: isOffline
                                              ? 'Unable to load your recipes while offline'
                                              : 'Couldn\'t load recipes. Tap to retry.',
                                          leadingIcon: isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                                          onRetry: () {
                                            _refreshAllSections(context);
                                          },
                                        );
                                      }
                                      // Show empty state if no recipes
                                      if (saved.isEmpty) {
                                        return _buildSectionMessage(
                                          context,
                                          title: 'Your Recipes',
                                          message: 'Start creating or importing recipes to see them here!',
                                          leadingIcon: Icons.add_circle_outline_rounded,
                                          onRetry: null, // No retry for empty state
                                        );
                                      }
                                      return _buildRecipeCarousel(
                                        context,
                                        title: 'Your Recipes',
                                        recipes: saved.take(10).toList(),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            SizedBox(height: AppSpacing.responsive(context)),
                            // --- Community Recipes carousel ---
                            // Wrap with TutorialShowcase at this level so GlobalKey is always attached
                            TutorialShowcase(
                              showcaseKey: TutorialKeys.homeCommunity,
                              title: 'Community Recipes 👥',
                              description:
                                  'Discover recipes shared by other users. Save your favorites and get inspired by the community!',
                              child: Consumer<DynamicUiProvider>(
                                builder: (context, dynamicUi, _) {
                                  if (!(dynamicUi.config?.isSectionVisible(
                                        'communityCarousel',
                                      ) ??
                                      true)) {
                                    return const SizedBox.shrink();
                                  }
                                  return Consumer<RecipeProvider>(
                                    builder: (context, recipeProvider, _) {
                                      final community = recipeProvider.communityRecipes
                                          .take(10)
                                          .toList();
                                      // Show loading if still booting or loading
                                      if (_isBooting || recipeProvider.isLoading) {
                                        return _buildSectionLoading(
                                          context,
                                          title: 'Community',
                                          height: 180,
                                        );
                                      }
                                      // Show error if failed to load
                                      if (community.isEmpty &&
                                          recipeProvider.error != null) {
                                        final isOffline = recipeProvider.error!.isNetworkError;
                                        return _buildSectionMessage(
                                          context,
                                          title: 'Community',
                                          message: isOffline
                                              ? 'Connect to browse community recipes'
                                              : 'Couldn\'t load community recipes. Tap to retry.',
                                          leadingIcon: isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                                          onRetry: () {
                                            _refreshAllSections(context);
                                          },
                                        );
                                      }
                                      // Show empty state if no community recipes available
                                      if (community.isEmpty) {
                                        return _buildSectionMessage(
                                          context,
                                          title: 'Community',
                                          message: 'No community recipes available yet',
                                          leadingIcon: Icons.people_outline_rounded,
                                          onRetry: () {
                                            _refreshAllSections(context);
                                          },
                                        );
                                      }
                                      return _buildCommunityCarousel(
                                        context,
                                        title: 'Community',
                                        recipes: community,
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            SizedBox(height: AppSpacing.responsive(context)),
                            // --- Discover & Try carousel ---
                            // Wrap with TutorialShowcase at this level so GlobalKey is always attached
                            TutorialShowcase(
                              showcaseKey: TutorialKeys.homeDiscover,
                              title: 'Explore & Inspire 🔍',
                              description:
                                  'Discover new recipes to try! Browse trending dishes and find your next favorite meal.',
                              child: Consumer<DynamicUiProvider>(
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
                                                    !recipeProvider.userRecipes
                                                        .any((u) => u.id == r.id),
                                              )
                                              .take(10)
                                              .toList();
                                      // Show loading if still booting or loading
                                      if (_isBooting || recipeProvider.isLoading) {
                                        return _buildSectionLoading(
                                          context,
                                          title: 'Discover & Try',
                                          height: 180,
                                        );
                                      }
                                      // Show error if failed to load
                                      if (random.isEmpty &&
                                          recipeProvider.error != null) {
                                        final isOffline = recipeProvider.error!.isNetworkError;
                                        return _buildSectionMessage(
                                          context,
                                          title: 'Discover & Try',
                                          message: isOffline
                                              ? 'Connect to discover new recipes'
                                              : 'Couldn\'t load recipes. Tap to retry.',
                                          leadingIcon: isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                                          onRetry: () {
                                            _refreshAllSections(context);
                                          },
                                        );
                                      }
                                      // Show empty state if no discover recipes available
                                      if (random.isEmpty) {
                                        return _buildSectionMessage(
                                          context,
                                          title: 'Discover & Try',
                                          message: 'No recipes to discover yet',
                                          leadingIcon: Icons.explore_outlined,
                                          onRetry: () {
                                            _refreshAllSections(context);
                                          },
                                        );
                                      }
                                      return _buildRecipeCarousel(
                                        context,
                                        title: 'Discover & Try',
                                        recipes: random,
                                      );
                                    },
                                  );
                                },
                              ),
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
                                // Ensure collections future is initialized
                                if (_collectionsFuture == null) {
                                  final collectionService =
                                      Provider.of<CollectionService>(
                                        context,
                                        listen: false,
                                      );
                                  _collectionsFuture = collectionService
                                      .getCollections(
                                        updateSpecialCollections: true,
                                      );
                                }
                                // Use cached collections future to avoid duplicate API calls
                                final collections = _collectionsFuture!.then(
                                  (value) => value.take(10).toList(),
                                );

                                return _buildCollectionCarousel(
                                  context,
                                  title: 'Collections',
                                  collections: collections,
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
    return TutorialShowcase(
      showcaseKey: TutorialKeys.homeHero,
      title: 'Welcome to RecipEase! 👋',
      description:
          'Your personal AI kitchen assistant. Discover, create, and organize recipes seamlessly.',
      targetPadding: const EdgeInsets.all(16),
      child: Padding(
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
                        // Check if dynamic UI config provides a custom hero image
                        final customHero = dynamicUi.config?.heroImageUrl;
                        
                        // Determine image source: use custom if provided, otherwise default local asset
                        final heroImage = (customHero != null && customHero.isNotEmpty)
                            ? customHero
                            : _localHeroImageAsset;
                        
                        // Check if it's a local asset (starts with 'assets/') or network URL
                        final isLocalAsset = heroImage.startsWith('assets/');

                        if (isLocalAsset) {
                          return Image.asset(
                            heroImage,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                          );
                        }

                        // Network image with fallback to default local asset
                        return Image.network(
                          heroImage,
                          fit: BoxFit.cover,
                          cacheWidth:
                              (constraints.maxWidth * devicePixelRatio).round(),
                          cacheHeight:
                              (constraints.maxHeight * devicePixelRatio)
                                  .round(),
                          filterQuality: FilterQuality.high,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback to local asset on network error
                            return Image.asset(
                              _localHeroImageAsset,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
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
                          if (hasUsernamePlaceholder &&
                              welcomeParts.length == 2)
                            RichText(
                              text: TextSpan(
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
                                children: [
                                  TextSpan(text: welcomeParts[0]),
                                  TextSpan(
                                    text: username,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
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
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
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
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
      ),
    );
  }

  /// Horizontal list of quick-access category cards.
  Widget _buildCategoryScroller(BuildContext context, {required String title}) {
    final categories = _quickCategories();
    final theme = Theme.of(context);
    return TutorialShowcase(
      showcaseKey: TutorialKeys.homeFeatures,
      title: 'Powerful Tools 🚀',
      description:
          'Import recipes from Instagram/TikTok, or use AI to generate new meals from your ingredients!',
      targetPadding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
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
      ),
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
        'Community',
        Icons.people_rounded,
        '/community',
        const Color(0xFF6C5CE7),
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
  /// Note: TutorialShowcase wrappers are applied at parent level in build()
  Widget _buildRecipeCarousel(
    BuildContext context, {
    required String title,
    required List<Recipe> recipes,
  }) {
    final theme = Theme.of(context);
    final isYourRecipes = title.contains('Your Recipes');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: GestureDetector(
            onTap: () {
              // Navigate based on the title
              if (isYourRecipes) {
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

  /// Builds a community recipe carousel section with user profile pics on cards.
  /// Note: TutorialShowcase wrapper is applied at the parent level in build()
  Widget _buildCommunityCarousel(
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
              Navigator.pushNamed(context, '/community');
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
              return _buildCommunityRecipeCard(context, recipe);
            },
          ),
        ),
      ],
    );
  }

  /// Builds a community recipe card with user profile pic in top right corner.
  Widget _buildCommunityRecipeCard(BuildContext context, Recipe recipe) {
    final theme = Theme.of(context);
    final cardWidth =
        AppBreakpoints.isDesktop(context)
            ? 220.0
            : AppBreakpoints.isTablet(context)
            ? 180.0
            : 140.0;
    
    // Get user photo URL and display name from recipe
    final photoUrl = recipe.sharedByPhotoUrl;
    final displayName = recipe.sharedByDisplayName ?? 'User';
    
    return GestureDetector(
      onLongPressStart: (details) {
        _showRecipeContextMenu(context, recipe, details.globalPosition);
      },
      child: InkWell(
        onTap:
            () => Navigator.pushNamed(
              context,
              '/recipeDetail',
              arguments: recipe,
            ),
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
                // User profile pic in top right corner
                Positioned(
                  top: AppBreakpoints.isDesktop(context) ? 10 : 8,
                  right: AppBreakpoints.isDesktop(context) ? 10 : 8,
                  child: Tooltip(
                    message: displayName,
                    child: Container(
                      width: AppBreakpoints.isDesktop(context) ? 36 : 28,
                      height: AppBreakpoints.isDesktop(context) ? 36 : 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: ImageUtils.buildProfileImage(
                          imageUrl: photoUrl,
                          width: AppBreakpoints.isDesktop(context) ? 36 : 28,
                          height: AppBreakpoints.isDesktop(context) ? 36 : 28,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            color: theme.colorScheme.primaryContainer,
                            child: Icon(
                              Icons.person,
                              size: AppBreakpoints.isDesktop(context) ? 20 : 16,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ),
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
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                ),
                              ],
                            )
                            : theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 4,
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
            () => Navigator.pushNamed(
              context,
              '/recipeDetail',
              arguments: recipe,
            ),
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
            final navigator = Navigator.of(context);
            Future.delayed(const Duration(milliseconds: 100), () {
              if (!mounted) return;
              navigator.pushNamed('/recipeDetail', arguments: recipe);
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  /// Builds a collection carousel section with a horizontal list of collection cards.
  Widget _buildCollectionCarousel(
    BuildContext context, {
    required String title,
    required Future<List<RecipeCollection>> collections,
  }) {
    final theme = Theme.of(context);

    return TutorialShowcase(
      showcaseKey: TutorialKeys.homeCollections,
      title: 'Smart Organization 📁',
      description:
          'Group recipes your way. Colors and icons are assigned automatically based on collection names!',
      targetPadding: const EdgeInsets.all(12),
      child: Column(
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
                        decorationColor:
                            Theme.of(context).colorScheme.onSurface,
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
      ),
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
                    Icons.arrow_forward_ios,
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

  // Helper method to get a contrasting icon color for better visibility
  Color _getIconColor(Color collectionColor) {
    // Calculate brightness of the collection color
    final brightness = collectionColor.computeLuminance();

    // If the color is light (brightness > 0.5), use a darker, more saturated version
    // If the color is dark (brightness <= 0.5), use a lighter version
    if (brightness > 0.5) {
      // For light colors, use a darker, more saturated version
      final hsl = HSLColor.fromColor(collectionColor);
      return hsl
          .withLightness((hsl.lightness * 0.4).clamp(0.0, 1.0))
          .withSaturation((hsl.saturation * 1.3).clamp(0.0, 1.0))
          .toColor();
    } else {
      // For dark colors, use a lighter, more vibrant version
      final hsl = HSLColor.fromColor(collectionColor);
      return hsl
          .withLightness((hsl.lightness * 1.8).clamp(0.0, 1.0))
          .withSaturation((hsl.saturation * 1.2).clamp(0.0, 1.0))
          .toColor();
    }
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
                      color: _getIconColor(collection.color),
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
    return TutorialShowcase(
      showcaseKey: TutorialKeys.navDrawerMenu,
      title: 'Navigation Menu 📱',
      description:
          'Tap here to access your profile, recipes, collections, and settings.',
      isCircular: true,
      targetPadding: const EdgeInsets.all(12),
      child: Padding(
        padding: EdgeInsets.all(
          AppSpacing.responsive(context, mobile: 8, tablet: 12, desktop: 16),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
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
                shape: BoxShape.circle,
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
      ),
    );
  }
}
