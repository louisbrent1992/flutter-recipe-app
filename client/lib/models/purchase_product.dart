import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter/material.dart';

/// Enum for different types of purchases
enum PurchaseType { consumable, nonConsumable, subscription }

/// Enum for specific product types
enum ProductType {
  // Consumables
  recipeImports15, // Quick pack
  recipeImports25,
  recipeGenerations25,

  // Non-consumables
  adFree,
  adFreePlus25Imports,
  adFreePlus25Generations,
  ultimateBundle, // Ad-free + 25 imports + 25 generations (50 total)
  // Subscriptions
  monthlyPremium,
  yearlyPremium,
  unlimitedPremium,
  unlimitedPremiumYearly,
}

/// Model class representing a purchase product
class PurchaseProduct {
  final String id;
  final String title;
  final String description;
  final ProductType productType;
  final PurchaseType purchaseType;
  final int? creditAmount; // For consumables
  final int? monthlyCredits; // For subscriptions
  final bool includesAdFree;
  final bool isBestValue;
  final ProductDetails? productDetails;
  final IconData icon; // Icon for the product
  final bool unlimitedUsage;

  PurchaseProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.productType,
    required this.purchaseType,
    this.creditAmount,
    this.monthlyCredits,
    this.includesAdFree = false,
    this.isBestValue = false,
    this.productDetails,
    required this.icon,
    this.unlimitedUsage = false,
  });

  PurchaseProduct copyWith({
    String? id,
    String? title,
    String? description,
    ProductType? productType,
    PurchaseType? purchaseType,
    int? creditAmount,
    int? monthlyCredits,
    bool? includesAdFree,
    bool? isBestValue,
    ProductDetails? productDetails,
    IconData? icon,
    bool? unlimitedUsage,
  }) {
    return PurchaseProduct(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      productType: productType ?? this.productType,
      purchaseType: purchaseType ?? this.purchaseType,
      creditAmount: creditAmount ?? this.creditAmount,
      monthlyCredits: monthlyCredits ?? this.monthlyCredits,
      includesAdFree: includesAdFree ?? this.includesAdFree,
      isBestValue: isBestValue ?? this.isBestValue,
      productDetails: productDetails ?? this.productDetails,
      icon: icon ?? this.icon,
      unlimitedUsage: unlimitedUsage ?? this.unlimitedUsage,
    );
  }

  String get price => productDetails?.price ?? _getMockPrice();

  String _getMockPrice() {
    switch (productType) {
      // Consumables
      case ProductType.recipeImports15:
        return '\$2.49';
      case ProductType.recipeImports25:
        return '\$3.99';
      case ProductType.recipeGenerations25:
        return '\$3.99';

      // Non-consumables
      case ProductType.adFree:
        return '\$4.99';
      case ProductType.adFreePlus25Imports:
        return '\$7.99';
      case ProductType.adFreePlus25Generations:
        return '\$7.99';
      case ProductType.ultimateBundle:
        return '\$11.99';

      // Subscriptions
      case ProductType.monthlyPremium:
        return '\$6.99/month';
      case ProductType.yearlyPremium:
        return '\$44.99/year';
      case ProductType.unlimitedPremium:
        return '\$19.99/month';
      case ProductType.unlimitedPremiumYearly:
        return '\$79.99/year';
    }
  }
}

/// Constants for product IDs
class ProductIds {
  // Consumables
  static const String recipeImports15 = 'recipease_imports_15'; // Quick pack
  static const String recipeImports25 = 'recipease_imports_25';
  static const String recipeGenerations25 = 'recipease_generations_25';

  // Non-consumables
  static const String adFree = 'recipease_ad_free_v2';
  static const String adFreePlus25Imports = 'recipease_ad_free_imports_25';
  static const String adFreePlus25Generations =
      'recipease_ad_free_generations_25';
  static const String ultimateBundle = 'recipease_ultimate_bundle_v2';

  // Subscriptions
  static const String monthlyPremium = 'recipease_premium_monthly';
  static const String yearlyPremium = 'recipease_premium_yearly';
  static const String unlimitedPremium = 'recipease_premium_unlimited';
  static const String unlimitedPremiumYearly =
      'recipease_premium_unlimited_yearly';

  /// Get all product IDs as a set
  static Set<String> get allProductIds => {
    recipeImports15,
    recipeImports25,
    recipeGenerations25,
    adFree,
    adFreePlus25Imports,
    adFreePlus25Generations,
    ultimateBundle,
    monthlyPremium,
    yearlyPremium,
    unlimitedPremium,
    unlimitedPremiumYearly,
  };

  /// Get product type from ID
  static ProductType? getProductType(String id) {
    switch (id) {
      case recipeImports15:
        return ProductType.recipeImports15;
      case recipeImports25:
        return ProductType.recipeImports25;
      case recipeGenerations25:
        return ProductType.recipeGenerations25;
      case adFree:
        return ProductType.adFree;
      case adFreePlus25Imports:
        return ProductType.adFreePlus25Imports;
      case adFreePlus25Generations:
        return ProductType.adFreePlus25Generations;
      case ultimateBundle:
        return ProductType.ultimateBundle;
      case monthlyPremium:
        return ProductType.monthlyPremium;
      case yearlyPremium:
        return ProductType.yearlyPremium;
      case unlimitedPremium:
        return ProductType.unlimitedPremium;
      case unlimitedPremiumYearly:
        return ProductType.unlimitedPremiumYearly;
      default:
        return null;
    }
  }
}

/// Predefined product configurations
class ProductConfigurations {
  static List<PurchaseProduct> get allProducts => [
    // Consumables
    PurchaseProduct(
      id: ProductIds.recipeImports15,
      title: 'Quick Import Pack',
      description:
          'Import 15 recipes from any cooking website. Perfect for trying the feature!',
      productType: ProductType.recipeImports15,
      purchaseType: PurchaseType.consumable,
      creditAmount: 15,
      icon: Icons.rocket_launch,
    ),
    PurchaseProduct(
      id: ProductIds.recipeImports25,
      title: '25 Recipe Imports',
      description:
          'Import 25 recipes from Instagram, TikTok, YouTube, AllRecipes, and thousands more sites',
      productType: ProductType.recipeImports25,
      purchaseType: PurchaseType.consumable,
      creditAmount: 25,
      isBestValue: true,
      icon: Icons.share,
    ),
    PurchaseProduct(
      id: ProductIds.recipeGenerations25,
      title: '25 Recipe Generations',
      description:
          'Generate 25 custom recipes based on your ingredients and preferences',
      productType: ProductType.recipeGenerations25,
      purchaseType: PurchaseType.consumable,
      creditAmount: 25,
      icon: Icons.auto_awesome,
    ),

    // Non-consumables
    PurchaseProduct(
      id: ProductIds.adFree,
      title: 'Ad-Free',
      description:
          'Remove all ads permanently. Clean, distraction-free cooking experience forever',
      productType: ProductType.adFree,
      purchaseType: PurchaseType.nonConsumable,
      includesAdFree: true,
      icon: Icons.block,
    ),
    PurchaseProduct(
      id: ProductIds.adFreePlus25Imports,
      title: 'Ad-Free + Import Starter',
      description:
          'Remove ads FOREVER + get 25 recipe imports. Perfect way to get started!',
      productType: ProductType.adFreePlus25Imports,
      purchaseType: PurchaseType.nonConsumable,
      creditAmount: 25,
      includesAdFree: true,
      icon: Icons.card_giftcard,
    ),
    PurchaseProduct(
      id: ProductIds.adFreePlus25Generations,
      title: 'Ad-Free + Recipe Pack',
      description:
          'Remove ads FOREVER + generate 25 recipes. Perfect for creative cooks!',
      productType: ProductType.adFreePlus25Generations,
      purchaseType: PurchaseType.nonConsumable,
      creditAmount: 25,
      includesAdFree: true,
      icon: Icons.palette,
    ),
    PurchaseProduct(
      id: ProductIds.ultimateBundle,
      title: 'Ultimate Bundle',
      description:
          'Remove ads forever + 25 recipe imports + 25 recipe generations. Everything you need!',
      productType: ProductType.ultimateBundle,
      purchaseType: PurchaseType.nonConsumable,
      creditAmount: 50, // 25 + 25
      includesAdFree: true,
      isBestValue: true,
      icon: Icons.local_fire_department,
    ),

    // Subscriptions
    PurchaseProduct(
      id: ProductIds.monthlyPremium,
      title: 'Premium - Monthly',
      description:
          'No ads + 25 recipe imports + 25 recipe generations every month. 7-day free trial!',
      productType: ProductType.monthlyPremium,
      purchaseType: PurchaseType.subscription,
      monthlyCredits: 50, // 25 + 25
      includesAdFree: true,
      icon: Icons.workspace_premium,
    ),
    PurchaseProduct(
      id: ProductIds.yearlyPremium,
      title: 'Premium - Yearly',
      description:
          'SAVE 46%! No ads + 25 recipe imports + 25 recipe generations/month. Only \$3.75/month. 7-day free trial!',
      productType: ProductType.yearlyPremium,
      purchaseType: PurchaseType.subscription,
      monthlyCredits: 50, // 25 + 25
      includesAdFree: true,
      icon: Icons.star_rounded,
    ),

    // Unlimited subscription
    PurchaseProduct(
      id: ProductIds.unlimitedPremium,
      title: 'Premium - Unlimited',
      description:
          'Unlimited imports and generations. No ads. Fair-use policy applies.',
      productType: ProductType.unlimitedPremium,
      purchaseType: PurchaseType.subscription,
      includesAdFree: true,
      unlimitedUsage: true,
      icon: Icons.all_inclusive,
    ),

    // Unlimited subscription (Yearly)
    PurchaseProduct(
      id: ProductIds.unlimitedPremiumYearly,
      title: 'Premium - Unlimited (Yearly)',
      description:
          'SAVE 67%! Unlimited imports and generations. No ads. Fair-use policy applies.',
      productType: ProductType.unlimitedPremiumYearly,
      purchaseType: PurchaseType.subscription,
      includesAdFree: true,
      unlimitedUsage: true,
      isBestValue: true,
      icon: Icons.all_inclusive,
    ),
  ];

  /// Get product configuration by ID
  static PurchaseProduct? getProductById(String id) {
    try {
      return allProducts.firstWhere((product) => product.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get products by type
  static List<PurchaseProduct> getProductsByType(PurchaseType type) {
    return allProducts
        .where((product) => product.purchaseType == type)
        .toList();
  }
}
