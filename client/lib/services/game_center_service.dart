import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

/// Service for managing Game Center leaderboards and achievements
/// Integrates with the chef ranking system
class GameCenterService {
  static final GameCenterService _instance = GameCenterService._internal();
  factory GameCenterService() => _instance;
  GameCenterService._internal();

  bool _isInitialized = false;
  bool _isAuthenticated = false;

  /// Leaderboard IDs - Configure these in App Store Connect
  static const String leaderboardChefStars = 'chef_stars_leaderboard';
  static const String leaderboardChefStarsAllTime =
      'chef_stars_all_time_leaderboard';
  static const String leaderboardRecipesSaved = 'recipes_saved_leaderboard';
  static const String leaderboardTotalRecipes = 'total_recipes_leaderboard';

  /// Achievement IDs - Configure these in App Store Connect
  /// Based on professional chef hierarchy (Brigade de Cuisine)
  static const String achievementNoviceChef =
      'achievement_commis_chef'; // 1 star - Junior chef
  static const String achievementHomeCook =
      'achievement_line_cook'; // 2 stars - Chef de Partie
  static const String achievementSkilledChef =
      'achievement_sous_chef'; // 3 stars - Assistant head chef
  static const String achievementExpertChef =
      'achievement_executive_chef'; // 4 stars - Chef de Cuisine
  static const String achievementMasterChef =
      'achievement_master_chef'; // 5 stars - Master Chef
  static const String achievementFirstRecipe = 'achievement_first_recipe';
  static const String achievement50Recipes = 'achievement_50_recipes';
  static const String achievement100Recipes = 'achievement_100_recipes';
  static const String achievement300Recipes = 'achievement_300_recipes';
  static const String achievement500Recipes = 'achievement_500_recipes';
  static const String achievement1000Recipes = 'achievement_1000_recipes';
  static const String achievementFirstGeneration =
      'achievement_first_generation';
  static const String achievementFirstImport = 'achievement_first_import';

  /// Initialize Game Center
  Future<bool> initialize() async {
    if (_isInitialized) return _isAuthenticated;

    try {
      // Check if Game Center is available (iOS only)
      if (defaultTargetPlatform != TargetPlatform.iOS) {
        debugPrint('Game Center is only available on iOS');
        _isInitialized = true;
        return false;
      }

      // Sign in to Game Center
      await signIn();
      _isInitialized = true;
      return _isAuthenticated;
    } catch (e) {
      debugPrint('Error initializing Game Center: $e');
      _isInitialized = true;
      return false;
    }
  }

  /// Sign in to Game Center
  Future<bool> signIn() async {
    try {
      await GamesServices.signIn();
      _isAuthenticated = true;
      debugPrint('✅ Game Center signed in successfully');
      return true;
    } catch (e) {
      debugPrint('⚠️ Game Center sign-in failed: $e');
      _isAuthenticated = false;
      return false;
    }
  }

  /// Check if user is authenticated
  bool get isAuthenticated => _isAuthenticated;

  /// Submit chef stars to leaderboard
  /// Stars are calculated based on recipe difficulty and count (1-5 stars)
  Future<void> submitChefStars(int stars) async {
    if (!_isAuthenticated) {
      debugPrint(
        'Game Center not authenticated, skipping leaderboard submission',
      );
      return;
    }

    try {
      // Live leaderboard (Most Recent)
      await GamesServices.submitScore(
        score: Score(
          iOSLeaderboardID: leaderboardChefStars,
          androidLeaderboardID: leaderboardChefStars,
          value: stars,
        ),
      );
      // All-Time leaderboard (Best Score)
      await GamesServices.submitScore(
        score: Score(
          iOSLeaderboardID: leaderboardChefStarsAllTime,
          androidLeaderboardID: leaderboardChefStarsAllTime,
          value: stars,
        ),
      );
      debugPrint(
        '✅ Submitted chef stars: $stars to live and all-time leaderboards',
      );
    } catch (e) {
      debugPrint('Error submitting chef stars: $e');
    }
  }

  /// Submit total recipes saved to leaderboard
  Future<void> submitRecipesSaved(int count) async {
    if (!_isAuthenticated) {
      debugPrint(
        'Game Center not authenticated, skipping leaderboard submission',
      );
      return;
    }

    try {
      await GamesServices.submitScore(
        score: Score(
          iOSLeaderboardID: leaderboardRecipesSaved,
          androidLeaderboardID: leaderboardRecipesSaved,
          value: count,
        ),
      );
      debugPrint('✅ Submitted recipes saved: $count to leaderboard');
    } catch (e) {
      debugPrint('Error submitting recipes saved: $e');
    }
  }

  /// Show leaderboards
  Future<void> showLeaderboards() async {
    if (!_isAuthenticated) {
      debugPrint('Game Center not authenticated, attempting sign-in...');
      final signedIn = await signIn();
      if (!signedIn) {
        debugPrint('Unable to show leaderboards - not authenticated');
        return;
      }
    }

    try {
      await GamesServices.showLeaderboards(
        iOSLeaderboardID: leaderboardChefStars,
        androidLeaderboardID: leaderboardChefStars,
      );
    } catch (e) {
      debugPrint('Error showing leaderboards: $e');
    }
  }

  /// Unlock achievement based on chef ranking
  /// Now requires minimum recipe counts to prevent early unlocks
  Future<void> unlockChefAchievement(int stars, {required int recipeCount}) async {
    if (!_isAuthenticated) return;

    try {
      String? achievementId;
      
      // Require minimum recipe counts for each chef level
      switch (stars) {
        case 1:
          if (recipeCount >= 1) {
            achievementId = achievementNoviceChef; // Commis Chef - 1 recipe minimum
          }
          break;
        case 2:
          if (recipeCount >= 50) {
            achievementId = achievementHomeCook; // Line Cook - 50 recipes minimum
          }
          break;
        case 3:
          if (recipeCount >= 150) {
            achievementId = achievementSkilledChef; // Sous Chef - 150 recipes minimum
          }
          break;
        case 4:
          if (recipeCount >= 300) {
            achievementId = achievementExpertChef; // Executive Chef - 300 recipes minimum
          }
          break;
        case 5:
          if (recipeCount >= 500) {
            achievementId = achievementMasterChef; // Master Chef - 500 recipes minimum
          }
          break;
        default:
          return;
      }

      if (achievementId != null) {
        await GamesServices.unlock(
          achievement: Achievement(
            iOSID: achievementId,
            androidID: achievementId,
          ),
        );
        debugPrint('✅ Unlocked achievement: $achievementId ($stars stars, $recipeCount recipes)');
      }
    } catch (e) {
      debugPrint('Error unlocking chef achievement: $e');
    }
  }

  /// Unlock recipe count achievements
  Future<void> unlockRecipeCountAchievement(int recipeCount) async {
    if (!_isAuthenticated) return;

    try {
      String? achievementId;
      if (recipeCount == 1) {
        achievementId = achievementFirstRecipe;
      } else if (recipeCount == 50) {
        achievementId = achievement50Recipes;
      } else if (recipeCount == 100) {
        achievementId = achievement100Recipes;
      } else if (recipeCount == 300) {
        achievementId = achievement300Recipes;
      } else if (recipeCount == 500) {
        achievementId = achievement500Recipes;
      } else if (recipeCount == 1000) {
        achievementId = achievement1000Recipes;
      }

      if (achievementId != null) {
        await GamesServices.unlock(
          achievement: Achievement(
            iOSID: achievementId,
            androidID: achievementId,
          ),
        );
        debugPrint(
          '✅ Unlocked achievement: $achievementId ($recipeCount recipes)',
        );
      }
    } catch (e) {
      debugPrint('Error unlocking recipe count achievement: $e');
    }
  }

  /// Unlock first generation achievement
  Future<void> unlockFirstGeneration() async {
    if (!_isAuthenticated) return;

    try {
      await GamesServices.unlock(
        achievement: Achievement(
          iOSID: achievementFirstGeneration,
          androidID: achievementFirstGeneration,
        ),
      );
      debugPrint('✅ Unlocked achievement: First Recipe Generation');
    } catch (e) {
      debugPrint('Error unlocking first generation achievement: $e');
    }
  }

  /// Unlock first import achievement
  Future<void> unlockFirstImport() async {
    if (!_isAuthenticated) return;

    try {
      await GamesServices.unlock(
        achievement: Achievement(
          iOSID: achievementFirstImport,
          androidID: achievementFirstImport,
        ),
      );
      debugPrint('✅ Unlocked achievement: First Recipe Import');
    } catch (e) {
      debugPrint('Error unlocking first import achievement: $e');
    }
  }

  /// Show achievements
  Future<void> showAchievements() async {
    if (!_isAuthenticated) {
      debugPrint('Game Center not authenticated, attempting sign-in...');
      final signedIn = await signIn();
      if (!signedIn) {
        debugPrint('Unable to show achievements - not authenticated');
        return;
      }
    }

    try {
      await GamesServices.showAchievements();
    } catch (e) {
      debugPrint('Error showing achievements: $e');
    }
  }

  /// Sync chef ranking with Game Center
  /// Call this whenever the chef ranking changes
  Future<void> syncChefRanking({
    required int stars,
    required int recipeCount,
  }) async {
    if (!_isAuthenticated) {
      // Try to initialize if not authenticated
      await initialize();
      if (!_isAuthenticated) return;
    }

    // Submit to leaderboards
    await submitChefStars(stars);
    await submitRecipesSaved(recipeCount);

    // Unlock achievements - now with recipe count requirement
    await unlockChefAchievement(stars, recipeCount: recipeCount);
    await unlockRecipeCountAchievement(recipeCount);
  }

  /// Get player's Game Center display name
  Future<String?> getPlayerDisplayName() async {
    if (!_isAuthenticated) return null;

    try {
      // Note: games_services doesn't directly expose player name
      // This would need native implementation if needed
      return null;
    } catch (e) {
      debugPrint('Error getting player display name: $e');
      return null;
    }
  }
}
