const express = require("express");
const router = express.Router();

// Simple dynamic UI config endpoint
// You can update this JSON (or back it with Firestore) without changing the app
router.get("/ui/config", (req, res) => {
  const now = new Date();
  const config = {
    version: 1,
    fetchedAt: now.toISOString(),
    quickActions: [
      { icon: "link", text: "Import", url: "app://import" },
      { icon: "sparkles", text: "Generate", url: "app://generate" },
      { icon: "local_fire_department", text: "Holiday", url: "app://discover" },
    ],
    modal: {
      id: "winter_promo",
      title: "Winter Cooking Week",
      body: "Warm up with seasonal recipes and save on Unlimited (Yearly).",
      ctaText: "See Deals",
      ctaUrl: "app://subscription",
      dismissible: true,
      startAt: null,
      endAt: null
    },
    banners: [
      {
        id: "seasonal_home",
        placement: "home_top",
        title: "Holiday Recipes",
        subtitle: "Warm flavors for cozy nights",
        ctaText: "Discover",
        ctaUrl: "app://discover",
        imageUrl: null,
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


