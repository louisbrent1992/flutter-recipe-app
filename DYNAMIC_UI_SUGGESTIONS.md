# Dynamic UI Configuration Suggestions

This document outlines suggestions for additional dynamic UI elements that can be controlled from the server without requiring an app update.

## ✅ Currently Implemented

1. **Hero Image** - Home screen hero image (just added)
2. **Banners** - Promotional banners with placement, priority, and scheduling
3. **Global Background** - App-wide background colors/gradients

## 🎯 Recommended Additions

### 1. **Welcome Message Customization**
- **Field**: `welcomeMessage` (string)
- **Usage**: Customize the "Welcome, [Username]" text on home screen
- **Example**: "Welcome back, [Username]!" or "Good morning, [Username]!"
- **Placement**: `home_hero_text`

### 2. **Subtitle/Description Text**
- **Field**: `heroSubtitle` (string)
- **Usage**: Customize the "What would you like to cook today?" text
- **Example**: Seasonal messages like "Try our holiday favorites!" or "New recipes added this week!"
- **Placement**: `home_hero_subtitle`

### 3. **Feature Section Ordering**
- **Field**: `featureOrder` (array of strings)
- **Usage**: Reorder the Features section items without app update
- **Example**: `["Import Recipe", "Generate Recipes", "My Recipes", "My Collections", "Discover Recipes"]`
- **Placement**: `home_features`

### 4. **Section Visibility Toggles**
- **Field**: `sectionVisibility` (object)
- **Usage**: Show/hide entire sections (e.g., hide Collections carousel during maintenance)
- **Example**: 
  ```json
  {
    "collectionsCarousel": true,
    "discoverCarousel": true,
    "yourRecipesCarousel": true,
    "featuresSection": true
  }
  ```
- **Placement**: `home_sections`

### 5. **Color Theme Overrides**
- **Field**: `themeOverrides` (object)
- **Usage**: Temporarily override primary/accent colors for special events
- **Example**: 
  ```json
  {
    "primaryColor": "#FF6B35",
    "accentColor": "#F7931E",
    "startDate": "2024-12-01T00:00:00Z",
    "endDate": "2024-12-31T23:59:59Z"
  }
  ```
- **Placement**: `app_theme`

### 6. **Empty State Messages**
- **Field**: `emptyStateMessages` (object)
- **Usage**: Customize empty state messages for different screens
- **Example**:
  ```json
  {
    "myRecipes": "Start your culinary journey! Create or import your first recipe.",
    "discover": "Explore our curated collection of delicious recipes.",
    "collections": "Organize your favorite recipes into collections."
  }
  ```
- **Placement**: `empty_states`

### 7. **Onboarding Messages**
- **Field**: `onboardingMessages` (array)
- **Usage**: Show tips or hints to new users
- **Example**:
  ```json
  [
    {
      "id": "tip_1",
      "title": "Quick Tip",
      "message": "Swipe right on recipe cards to save them instantly!",
      "placement": "home",
      "priority": 10,
      "showOnce": true
    }
  ]
  ```
- **Placement**: `onboarding`

### 8. **Promotional Text Overrides**
- **Field**: `promotionalText` (object)
- **Usage**: Update promotional text in subscription/shop screens
- **Example**:
  ```json
  {
    "premiumTitle": "Unlock Premium Features",
    "premiumSubtitle": "Get unlimited access to all recipes",
    "discountText": "Limited Time: 50% Off",
    "ctaText": "Upgrade Now"
  }
  ```
- **Placement**: `subscription_screen`

### 9. **Category/Filter Customization**
- **Field**: `featuredCategories` (array)
- **Usage**: Highlight specific recipe categories on discover screen
- **Example**:
  ```json
  [
    {
      "id": "holiday",
      "name": "Holiday Recipes",
      "icon": "🎄",
      "priority": 10,
      "startDate": "2024-11-01T00:00:00Z",
      "endDate": "2025-01-15T23:59:59Z"
    }
  ]
  ```
- **Placement**: `discover_categories`

### 10. **App Bar Customization**
- **Field**: `appBarConfig` (object)
- **Usage**: Customize app bar title, logo visibility, or actions
- **Example**:
  ```json
  {
    "homeTitle": "RecipEase",
    "showLogo": true,
    "customActions": []
  }
  ```
- **Placement**: `app_bar`

## 📋 Implementation Priority

### High Priority (Quick Wins)
1. ✅ Hero Image (Done)
2. Welcome Message Customization
3. Hero Subtitle Text
4. Section Visibility Toggles

### Medium Priority (Moderate Impact)
5. Feature Section Ordering
6. Empty State Messages
7. Promotional Text Overrides

### Low Priority (Nice to Have)
8. Color Theme Overrides
9. Onboarding Messages
10. Category/Filter Customization
11. App Bar Customization

## 🔧 Technical Considerations

- All dynamic configs should have fallback values in the app
- Use versioning to handle breaking changes gracefully
- Consider caching with TTL to reduce server load
- Add date-based scheduling for time-sensitive content
- Support A/B testing by allowing multiple configs

## 📝 Example Server Response Structure

```json
{
  "version": 1,
  "fetchedAt": "2024-01-15T10:00:00Z",
  "heroImageUrl": "https://...",
  "welcomeMessage": "Welcome back, {username}!",
  "heroSubtitle": "What would you like to cook today?",
  "sectionVisibility": {
    "collectionsCarousel": true,
    "discoverCarousel": true,
    "yourRecipesCarousel": true,
    "featuresSection": true
  },
  "featureOrder": [
    "Import Recipe",
    "Generate Recipes",
    "My Recipes",
    "My Collections",
    "Discover Recipes"
  ],
  "banners": [...],
  "globalBackground": {...}
}
```

