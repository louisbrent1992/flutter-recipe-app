# Game Center Achievements & Leaderboards

This document provides a complete reference for all Game Center achievements and leaderboards implemented in RecipEase.

---

## Overview

RecipEase integrates with Apple Game Center to provide achievements and leaderboards that track your culinary journey. Achievements are based on the professional chef hierarchy (Brigade de Cuisine) and your recipe collection milestones.

**Platform Support:** iOS only (Game Center is not available on Android)

---

## Leaderboards

### 1. Chef Stars Leaderboard
- **ID:** `chef_stars_leaderboard`
- **Type:** Live (Most Recent)
- **Description:** Tracks your current chef star rating (1-5 stars)
- **How it works:** Your chef stars are calculated based on:
  - Average recipe difficulty (Easy = 1, Medium = 1.5, Hard = 2)
  - Recipe count bonuses:
    - 50+ recipes: +1 star
    - 100+ recipes: +2 stars
    - 300+ recipes: +3 stars
  - Final stars are clamped between 1 and 5

### 2. Chef Stars All-Time Leaderboard
- **ID:** `chef_stars_all_time_leaderboard`
- **Type:** All-Time (Best Score)
- **Description:** Tracks your highest chef star rating achieved
- **How it works:** Same calculation as live leaderboard, but tracks your best score

### 3. Recipes Saved Leaderboard
- **ID:** `recipes_saved_leaderboard`
- **Type:** Cumulative
- **Description:** Tracks the total number of recipes you've saved to your collection
- **How it works:** Increments each time you save a recipe

### 4. Total Recipes Leaderboard
- **ID:** `total_recipes_leaderboard`
- **Type:** Cumulative
- **Description:** Tracks your total recipe count (configured but may not be actively used)

---

## Achievements

### Chef Ranking Achievements

These achievements are based on the professional chef hierarchy and unlock as you progress through the chef star system.

#### 1. Commis Chef (Novice Chef)
- **ID:** `achievement_commis_chef`
- **Requirement:** Reach 1 chef star
- **Title:** Commis Chef
- **Description:** Junior chef learning the basics
- **How to unlock:** Start your culinary journey by saving recipes. Your first star is earned by having recipes in your collection.

#### 2. Line Cook (Home Cook)
- **ID:** `achievement_line_cook`
- **Requirement:** Reach 2 chef stars
- **Title:** Line Cook (Chef de Partie)
- **Description:** Station specialist - you're getting the hang of it!
- **How to unlock:** 
  - Save 10+ recipes, OR
  - Maintain an average difficulty that rounds to 2 stars

#### 3. Sous Chef (Skilled Chef)
- **ID:** `achievement_sous_chef`
- **Requirement:** Reach 3 chef stars
- **Title:** Sous Chef
- **Description:** Assistant head chef - you're becoming skilled!
- **How to unlock:**
  - Save 50+ recipes (+1 star bonus), OR
  - Achieve 3 stars through difficulty and recipe count combination

#### 4. Executive Chef (Expert Chef)
- **ID:** `achievement_executive_chef`
- **Requirement:** Reach 4 chef stars
- **Title:** Executive Chef (Chef de Cuisine)
- **Description:** Kitchen leader - you're an expert!
- **How to unlock:**
  - Save 100+ recipes (+2 stars bonus), OR
  - Achieve 4 stars through difficulty and recipe count combination

#### 5. Master Chef
- **ID:** `achievement_master_chef`
- **Requirement:** Reach 5 chef stars (maximum)
- **Title:** Master Chef
- **Description:** Culinary excellence - kitchen master!
- **How to unlock:**
  - Save 300+ recipes (+3 stars bonus), AND
  - Maintain high average difficulty
  - This is the highest achievement level

---

### Recipe Collection Achievements

These achievements unlock as you build your recipe collection.

#### 6. First Recipe
- **ID:** `achievement_first_recipe`
- **Requirement:** Save your first recipe
- **Description:** Welcome to your culinary journey!
- **How to unlock:** Save any recipe to your collection

#### 7. Recipe Collector (50 Recipes)
- **ID:** `achievement_50_recipes`
- **Requirement:** Save 50 recipes
- **Description:** You're building an impressive collection!
- **How to unlock:** Save 50 recipes to your collection

#### 8. Recipe Enthusiast (100 Recipes)
- **ID:** `achievement_100_recipes`
- **Requirement:** Save 100 recipes
- **Description:** You're a true recipe enthusiast!
- **How to unlock:** Save 100 recipes to your collection

#### 9. Recipe Master (300 Recipes)
- **ID:** `achievement_300_recipes`
- **Requirement:** Save 300 recipes
- **Description:** You've mastered recipe collection!
- **How to unlock:** Save 300 recipes to your collection

#### 10. Recipe Legend (1000 Recipes)
- **ID:** `achievement_1000_recipes`
- **Requirement:** Save 1000 recipes
- **Description:** You're a recipe legend!
- **How to unlock:** Save 1000 recipes to your collection (ultimate milestone)

---

### Feature Usage Achievements

These achievements unlock when you use specific app features for the first time.

#### 11. First Recipe Generation
- **ID:** `achievement_first_generation`
- **Requirement:** Generate your first AI recipe
- **Description:** You've created your first custom recipe!
- **How to unlock:** Use the AI recipe generation feature to create a recipe

#### 12. First Recipe Import
- **ID:** `achievement_first_import`
- **Requirement:** Import your first recipe from a URL
- **Description:** You've imported your first recipe!
- **How to unlock:** Use the recipe import feature to import a recipe from Instagram, TikTok, YouTube, or any website

---

## Chef Star Calculation System

Your chef stars are calculated using the following formula:

1. **Base Stars (1-2):** Calculated from average recipe difficulty
   - Easy recipes: 1.0 star each
   - Medium recipes: 1.5 stars each
   - Hard recipes: 2.0 stars each
   - Average is rounded to nearest integer

2. **Bonus Stars:** Added based on recipe count
   - 50+ recipes: +1 star
   - 100+ recipes: +2 stars
   - 300+ recipes: +3 stars

3. **Final Stars:** Clamped between 1 and 5 (maximum)

**Example Calculations:**
- 10 Easy recipes = 1 star (base) = **1 star total** → Commis Chef
- 50 Easy recipes = 1 star (base) + 1 star (bonus) = **2 stars total** → Line Cook
- 100 Medium recipes = 2 stars (base) + 2 stars (bonus) = **4 stars total** → Executive Chef
- 300 Hard recipes = 2 stars (base) + 3 stars (bonus) = **5 stars total** → Master Chef

---

## Achievement Unlock Conditions Summary

| Achievement | Unlock Condition | Category |
|------------|------------------|----------|
| Commis Chef | 1 chef star | Chef Ranking |
| Line Cook | 2 chef stars | Chef Ranking |
| Sous Chef | 3 chef stars | Chef Ranking |
| Executive Chef | 4 chef stars | Chef Ranking |
| Master Chef | 5 chef stars | Chef Ranking |
| First Recipe | Save 1 recipe | Collection |
| Recipe Collector | Save 50 recipes | Collection |
| Recipe Enthusiast | Save 100 recipes | Collection |
| Recipe Master | Save 300 recipes | Collection |
| Recipe Legend | Save 1000 recipes | Collection |
| First Generation | Generate 1 AI recipe | Feature Usage |
| First Import | Import 1 recipe from URL | Feature Usage |

---

## Technical Implementation

### Achievement IDs (for App Store Connect configuration)

All achievement IDs must be configured in App Store Connect under Game Center → Achievements.

**Chef Ranking:**
- `achievement_commis_chef`
- `achievement_line_cook`
- `achievement_sous_chef`
- `achievement_executive_chef`
- `achievement_master_chef`

**Recipe Collection:**
- `achievement_first_recipe`
- `achievement_50_recipes`
- `achievement_100_recipes`
- `achievement_300_recipes`
- `achievement_1000_recipes`

**Feature Usage:**
- `achievement_first_generation`
- `achievement_first_import`

### Leaderboard IDs (for App Store Connect configuration)

All leaderboard IDs must be configured in App Store Connect under Game Center → Leaderboards.

- `chef_stars_leaderboard` (Live/Most Recent)
- `chef_stars_all_time_leaderboard` (All-Time/Best Score)
- `recipes_saved_leaderboard` (Cumulative)
- `total_recipes_leaderboard` (Cumulative)

---

## Notes

- **Automatic Sync:** Achievements and leaderboards are automatically synced when:
  - You save a recipe
  - Your chef ranking changes
  - You generate or import a recipe

- **Game Center Sign-In:** Achievements only unlock if you're signed in to Game Center. The app will attempt to sign you in automatically.

- **iOS Only:** Game Center is only available on iOS. Android users will not see achievements or leaderboards.

- **Privacy:** All Game Center data is handled by Apple's Game Center service. No personal recipe data is shared with Game Center.

---

## App Store Connect Setup

To enable these achievements and leaderboards:

1. **Go to App Store Connect** → Your App → Game Center
2. **Create Achievements:**
   - Add each achievement ID listed above
   - Set appropriate point values (suggested: 10-100 points)
   - Add achievement descriptions and images
3. **Create Leaderboards:**
   - Add each leaderboard ID listed above
   - Set score format (Integer)
   - Configure sorting (Higher is better)
   - Set leaderboard type (Live vs All-Time)

---

*Last Updated: Based on current codebase implementation*

