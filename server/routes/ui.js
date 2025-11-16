const express = require("express");
const router = express.Router();
const fs = require("fs");
const path = require("path");

/**
 * Get daily rotating subtitle from cooking-subtitles.json
 * Uses date-based selection to ensure same subtitle throughout the day
 * @returns {string} Selected subtitle or default fallback
 */
function getDailySubtitle() {
  const defaultSubtitle = "What would you like to cook today?";
  
  try {
    const subtitlesPath = path.join(__dirname, "../data/cooking-subtitles.json");
    const fileContent = fs.readFileSync(subtitlesPath, "utf8");
    const subtitles = JSON.parse(fileContent);
    
    if (!Array.isArray(subtitles) || subtitles.length === 0) {
      console.warn("cooking-subtitles.json is empty or invalid, using default");
      return defaultSubtitle;
    }
    
    // Calculate day of year (1-365/366)
    const now = new Date();
    const start = new Date(now.getFullYear(), 0, 0);
    const dayOfYear = Math.floor((now - start) / (1000 * 60 * 60 * 24));
    
    // Create deterministic index based on year and day of year
    // This ensures same subtitle for same day, different each day
    const index = (now.getFullYear() * 365 + dayOfYear) % subtitles.length;
    
    return subtitles[index] || defaultSubtitle;
  } catch (error) {
    console.error("Error loading daily subtitle:", error.message);
    return defaultSubtitle;
  }
}

// Simple dynamic UI config endpoint
// You can update this JSON (or back it with Firestore) without changing the app
router.get("/ui/config", (req, res) => {
  const now = new Date();
  const config = {
    version: 1,
    fetchedAt: now.toISOString(),
    // Home screen hero image - can be updated without app release
    heroImageUrl: "https://res.cloudinary.com/client-images/image/upload/v1763258640/Recipe%20App/Gemini_Generated_Image_1isjyd1isjyd1isj_jv1rvc.png",
    // Welcome message - supports {username} placeholder
    welcomeMessage: "Welcome,", // Default: "Welcome," or customize like "Welcome back, {username}!"
    // Hero subtitle text - rotates daily from cooking-subtitles.json
    heroSubtitle: getDailySubtitle(),
    // Section visibility toggles - set to false to hide sections
    sectionVisibility: {
      yourRecipesCarousel: true,
      discoverCarousel: true,
      collectionsCarousel: true,
      featuresSection: true
    },
    globalBackground: {
      // Choose either imageUrl or colors (for gradient/solid)
      imageUrl: null,
      colors: ["#FFF3E0", "#FFE0B2"], // soft seasonal gradient (light theme example)
      animateGradient: true,
      kenBurns: true,
      opacity: 1.0
    },
    banners: [
      {
        id: "seasonal_home",
        placement: "home_top",
        title: "Holiday Recipes",
        subtitle: "Warm flavors for cozy nights",
        ctaText: "Discover",
        ctaUrl: "app://discover?tag=holliday, fall,thanksgiving, turkey, christmas, winter, pumpkin, cranberry, cinnamon",
        imageUrl: "https://res.cloudinary.com/client-images/image/upload/v1762055982/Recipe%20App/holliday_recipes_banner_tmk4u3.png",
        backgroundColor: "#FFF3E0",
        textColor: "#7B3F00",
        priority: 10,
        startAt: null,
        endAt: null
      },
      {
        id: "shop_discount",
        placement: "shop_top",
        title: "Limited-Time Offer",
        subtitle: "Save 67% on Unlimited (Yearly)",
        ctaText: "Shop Now",
        ctaUrl: "app://subscription", // open in-app route
        imageUrl: null,
        backgroundColor: "#E8F5E9",
        textColor: "#1B5E20",
        priority: 20,
        startAt: null,
        endAt: null
      }
    ]
  };
  res.json({ success: true, data: config });
});

module.exports = router;


// Notifications configuration (similar to Dynamic UI)
// Exposes schedule, copy, and deeplink args per category.
router.get("/ui/notifications", (req, res) => {
  const config = {
    version: 1,
    categories: [
      {
        key: "dailyInspiration",
        enabledDefault: true,
        schedule: { type: "daily", hour: 14, minute: 0 }, // 2:00 PM - Afternoon inspiration for any meal
        title: "Today's Picks 🍽️",
        body: "Handpicked recipes we think you'll love.",
        route: "/randomRecipe",
        args: {},
      },
      {
        key: "mealPrep",
        enabledDefault: true,
        schedule: { type: "weekly", weekday: 0, hour: 9, minute: 0 }, // Sunday 9:00 AM - Morning meal prep planning
        title: "Meal Prep Sunday 🍱",
        body: "Plan your week with batch-friendly recipes.",
        route: "/discover",
        args: { tag: "meal prep, mealprep, batch cooking, prep ahead" },
      },
      {
        key: "seasonal",
        enabledDefault: true,
        schedule: { type: "weekly", weekday: 5, hour: 17, minute: 0 }, // Friday 5:00 PM - Weekend cooking inspiration
        title: "Holliday Favorites 🎄",
        body: "New festive recipes just dropped.",
        route: "/discover",
        args: { tag: "holliday, holiday, holidays, fall, autumn, thanksgiving, turkey, christmas, winter, pumpkin" },
      },
      {
        key: "quickMeals",
        enabledDefault: true,
        schedule: { type: "weekly", weekday: 2, hour: 17, minute: 0 }, // Tuesday 5:00 PM - Right before dinner time
        title: "20-Minute Dinners ⏱️",
        body: "Fast, tasty, and minimal cleanup.",
        route: "/discover",
        args: { tag: "easy, quick, fast, 20 minutes, 15 minutes, 30 minutes, minimal cleanup, simple, speedy, fast dinner" },
      },
      {
        key: "budget",
        enabledDefault: true,
        schedule: { type: "weekly", weekday: 3, hour: 17, minute: 0 }, // Wednesday 5:00 PM - Mid-week budget check
        title: "Save on Groceries 💸",
        body: "Delicious meals under $10.",
        route: "/discover",
        args: { tag: "budget, budget friendly, under $10, under $5, frugal, cheap, affordable, inexpensive, economical, cost effective" },
      },
      {
        key: "keto",
        enabledDefault: false,
        schedule: { type: "weekly", weekday: 1, hour: 9, minute: 0 }, // Monday 9:00 AM - Start week with healthy choices
        title: "Keto Spotlight 🥑",
        body: "Popular low-carb recipes this week.",
        route: "/discover",
        args: { tag: "keto, low-carb, ketogenic, keto-friendly, keto-diet, keto-recipes, low carb, lowcarb, no carb, zero carb" },
      },
    ],
  };
  res.json({ success: true, data: config });
});

