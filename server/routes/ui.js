const express = require("express");
const router = express.Router();

// Simple dynamic UI config endpoint
// You can update this JSON (or back it with Firestore) without changing the app
router.get("/ui/config", (req, res) => {
  const now = new Date();
  const config = {
    version: 1,
    fetchedAt: now.toISOString(),
    // Home screen hero image - can be updated without app release
    heroImageUrl: "https://res.cloudinary.com/client-images/image/upload/v1763258640/Recipe%20App/Gemini_Generated_Image_1isjyd1isjyd1isj_jv1rvc.png",
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
        schedule: { type: "daily", hour: 9, minute: 0 },
        title: "Today’s Picks 🍽️",
        body: "Handpicked recipes we think you’ll love.",
        route: "/discover",
        args: { tag: "", random: "true" },
      },
      {
        key: "mealPrep",
        enabledDefault: true,
        schedule: { type: "weekly", weekday: 0, hour: 17, minute: 0 }, // Sunday
        title: "Meal Prep Sunday 🍱",
        body: "Plan your week with batch-friendly recipes.",
        route: "/discover",
        args: { tag: "meal prep, batch cooking, prep ahead, prep for the week" },
      },
      {
        key: "seasonal",
        enabledDefault: true,
        schedule: { type: "weekly", weekday: 5, hour: 12, minute: 0 }, // Friday
        title: "Holliday Favorites 🎄",
        body: "New festive recipes just dropped.",
        route: "/discover",
        args: { tag: "holliday, fall, thanksgiving, turkey, christmas, winter, pumpkin, cranberry, cinnamon" },
      },
      {
        key: "quickMeals",
        enabledDefault: true,
        schedule: { type: "weekly", weekday: 2, hour: 18, minute: 0 }, // Tuesday
        title: "20-Minute Dinners ⏱️",
        body: "Fast, tasty, and minimal cleanup.",
        route: "/discover",
        args: { tag: "easy, 20 minutes, quick, minimal cleanup" },
      },
      {
        key: "budget",
        enabledDefault: true,
        schedule: { type: "weekly", weekday: 3, hour: 18, minute: 0 }, // Wednesday
        title: "Save on Groceries 💸",
        body: "Delicious meals under $10.",
        route: "/discover",
        args: { tag: "budget, under $10, frugal, cheap, affordable" },
      },
      {
        key: "keto",
        enabledDefault: false,
        schedule: { type: "weekly", weekday: 1, hour: 12, minute: 0 }, // Monday
        title: "Keto Spotlight 🥑",
        body: "Popular low-carb recipes this week.",
        route: "/discover",
        args: { tag: "keto" },
      },
    ],
  };
  res.json({ success: true, data: config });
});

