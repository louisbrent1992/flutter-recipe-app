const express = require("express");
const router = express.Router();

// Simple dynamic UI config endpoint
// You can update this JSON (or back it with Firestore) without changing the app
router.get("/ui/config", (req, res) => {
  const now = new Date();
  const config = {
    version: 1,
    fetchedAt: now.toISOString(),
    banners: [
      {
        id: "seasonal_home",
        placement: "home_top",
        title: "Holiday Recipes",
        subtitle: "Warm flavors for cozy nights",
        ctaText: "Discover",
        ctaUrl: "app://discover",
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
        subtitle: "Save 20% on Unlimited (Yearly)",
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


