import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recipease/providers/auth_provider.dart';
import 'package:recipease/services/collection_service.dart';
import '../providers/user_profile_provider.dart';
import '../components/custom_app_bar.dart';
import '../components/nav_drawer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/theme.dart';
import '../providers/recipe_provider.dart';
import '../models/recipe.dart';
import '../models/recipe_collection.dart';
import '../components/floating_bottom_bar.dart';

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
  final String _heroImageUrl = 'assets/images/hero_image.jpg';

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

        // Fetch a small set of random recipes for discovery
        recipeProvider.searchExternalRecipes(query: '', limit: 10);
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
        leading: Container(
          margin: AppSpacing.allResponsive(context),
          clipBehavior: Clip.antiAlias,
          width: AppSizing.responsiveIconSize(
            context,
            mobile: 40,
            tablet: 44,
            desktop: 48,
          ),
          height: AppSizing.responsiveIconSize(
            context,
            mobile: 40,
            tablet: 44,
            desktop: 48,
          ),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.surface.withValues(alpha: 0.8),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.08),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: IconButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(Colors.transparent),
                overlayColor: WidgetStateProperty.all(
                  colorScheme.primary.withValues(alpha: 0.1),
                ),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              icon: Icon(
                Icons.menu_rounded,
                color: colorScheme.primary.withValues(alpha: 0.8),
              ),
              iconSize: AppSizing.responsiveIconSize(context),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: AppSizing.responsiveIconSize(
                  context,
                  mobile: 40,
                  tablet: 44,
                  desktop: 48,
                ),
                minHeight: AppSizing.responsiveIconSize(
                  context,
                  mobile: 40,
                  tablet: 44,
                  desktop: 48,
                ),
              ),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ),
        ),
      ),
      drawer: const NavDrawer(),
      body: Stack(
        children: [
          SafeArea(
            child: Consumer<UserProfileProvider>(
              builder: (context, profile, _) {
                if (profile.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colorScheme.surface,
                        colorScheme.surface.withValues(alpha: 0.8),
                      ],
                    ),
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
                        _buildHeroSection(context),
                        SizedBox(height: AppSpacing.responsive(context)),
                        // --- Your Recipes carousel ---
                        Consumer<RecipeProvider>(
                          builder: (context, recipeProvider, _) {
                            final saved = recipeProvider.userRecipes;
                            if (saved.isEmpty) return const SizedBox();
                            return _buildRecipeCarousel(
                              context,
                              title: 'Your Recipes',
                              recipes: saved.take(10).toList(),
                            );
                          },
                        ),
                        SizedBox(height: AppSpacing.responsive(context)),
                        // --- Discover & Try carousel ---
                        Consumer<RecipeProvider>(
                          builder: (context, recipeProvider, _) {
                            final random = recipeProvider.generatedRecipes
                                .where(
                                  (r) =>
                                      !recipeProvider.userRecipes.any(
                                        (u) => u.id == r.id,
                                      ),
                                );
                            if (random.isEmpty) return const SizedBox();
                            return _buildRecipeCarousel(
                              context,
                              title: 'Discover & Try',
                              recipes: random.take(10).toList(),
                            );
                          },
                        ),
                        SizedBox(height: AppSpacing.responsive(context)),
                        // --- Collections carousel ---
                        Consumer<CollectionService>(
                          builder: (context, collectionProvider, _) {
                            final collections = collectionProvider
                                .getCollections(updateSpecialCollections: true)
                                .then((value) => value.take(10).toList());
                            return _buildCollectionCarousel(
                              context,
                              title: 'Collections',
                              collections: collections,
                            );
                          },
                        ),

                        SizedBox(height: AppSpacing.responsive(context)),
                        SizedBox(height: AppSpacing.responsive(context)),
                        // Category scroller with quick links
                        _buildCategoryScroller(context, title: 'Quick Links'),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Floating bottom bar
          FloatingBottomBar(),
        ],
      ),
    );
  }

  /// Builds the top hero banner with an enticing recipe photo and overlay text.
  Widget _buildHeroSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          // Background image
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.asset(
              _heroImageUrl,
              fit: BoxFit.contain,
              cacheWidth: 800, // Add cache width to optimize memory
              cacheHeight: 450, // Add cache height to optimize memory
              filterQuality:
                  FilterQuality.medium, // Adjust quality for better performance
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.primary.withValues(alpha: 0.3),
                        colorScheme.primary.withValues(alpha: 0.7),
                        colorScheme.primary,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: colorScheme.onPrimary,
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load image',
                          style: TextStyle(
                            color: colorScheme.onPrimary,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Please check the image file',
                          style: TextStyle(
                            color: colorScheme.onPrimary.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    colorScheme.surface.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),
          // Text overlay
          Padding(
            padding: AppSpacing.allResponsive(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  username,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'What would you like to cook today?',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
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
          padding: const EdgeInsets.all(8.0),
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
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.secondary,

                      decorationColor: theme.colorScheme.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => SizedBox(width: AppSpacing.sm),
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
    return SizedBox(
      height: 100,
      width: 200,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, cat.route),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cat.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(cat.icon, color: cat.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        cat.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getCategoryDescription(cat.title),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                          height: 1.3,
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
    );
  }

  /// Helper to define quick categories with consistent data.
  List<_CategoryItem> _quickCategories() {
    return [
      _CategoryItem(
        'My Recipes',
        Icons.restaurant_menu_rounded,
        '/myRecipes',
        Colors.orange,
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
        Colors.blue,
      ),
      _CategoryItem(
        'Favorite Recipes',
        Icons.favorite,
        '/favorites',
        Colors.red,
      ),
      _CategoryItem(
        'Import Recipe',
        Icons.ios_share_rounded,
        '/import',
        Colors.green,
      ),
      _CategoryItem(
        'Generate Recipe',
        Icons.auto_awesome,
        '/generate',
        Colors.purple,
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
      case 'Favorite Recipes':
        return 'Your bookmarked recipes for quick access';
      case 'Import Recipe':
        return 'Add recipes from websites, blogs, and social media';
      case 'Generate Recipe':
        return 'Create custom recipes with AI assistance';
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
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.secondary,

                      decorationColor: theme.colorScheme.secondary,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: theme.colorScheme.secondary,
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
    return InkWell(
      onTap:
          () =>
              Navigator.pushNamed(context, '/recipeDetail', arguments: recipe),
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Image
              Positioned.fill(
                child: Image.network(
                  recipe.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) => Container(
                        color: theme.colorScheme.secondary.withValues(
                          alpha: 0.1,
                        ),
                        child: Icon(
                          Icons.restaurant,
                          size: AppSizing.responsiveIconSize(
                            context,
                            mobile: 40,
                            tablet: 48,
                            desktop: 56,
                          ),
                          color: theme.colorScheme.primary,
                        ),
                      ),
                ),
              ),
              // Gradient overlay bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 60,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black54],
                    ),
                  ),
                ),
              ),
              // Title
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Text(
                  recipe.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
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
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.secondary,
                      decorationColor: theme.colorScheme.secondary,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: theme.colorScheme.secondary,
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
              if (!snapshot.hasData) return const SizedBox();
              final collections = snapshot.data!;
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

  /// Builds an individual collection card used within the collection carousel.
  Widget _buildCollectionCard(
    BuildContext context,
    RecipeCollection collection,
  ) {
    final theme = Theme.of(context);
    final hasRecipes = collection.recipes.isNotEmpty;
    final recipesWithImages =
        collection.recipes.where((r) => r.imageUrl.isNotEmpty).toList();

    return SizedBox(
      width: 180,
      child: Card(
        elevation: 4,
        shadowColor: collection.color.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          onTap:
              () => Navigator.pushNamed(
                context,
                '/collectionDetail',
                arguments: collection,
              ),
          borderRadius: BorderRadius.circular(20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
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
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      collection.icon,
                      size: 20,
                      color: collection.color,
                    ),
                  ),
                ),

                // Collection info (bottom)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Collection name
                      Text(
                        collection.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Recipe count with icon
                      Row(
                        children: [
                          Icon(
                            Icons.restaurant_menu_rounded,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${collection.recipes.length} ${collection.recipes.length == 1 ? 'recipe' : 'recipes'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
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
}
