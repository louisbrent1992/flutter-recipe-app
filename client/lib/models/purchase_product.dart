import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter/material.dart';

/// Enum for different types of purchases
enum PurchaseType { consumable, nonConsumable, subscription }

/// Enum for specific product types
enum ProductType {
  // Consumables
  recipeImports10, // Quick pack
  recipeImports20,
  recipeGenerations50,

  // Non-consumables
  adFree,
  adFreePlus20Imports,
  adFreePlus50Generations,
  ultimateBundle, // Ad-free + 30 imports + 50 generations
  // Subscriptions
  monthlyPremium,
  yearlyPremium,
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
    );
  }

  String get price => productDetails?.price ?? _getMockPrice();

  String _getMockPrice() {
    switch (productType) {
      // Consumables
      case ProductType.recipeImports10:
        return '\$2.49';
      case ProductType.recipeImports20:
        return '\$3.99';
      case ProductType.recipeGenerations50:
        return '\$4.99';

      // Non-consumables
      case ProductType.adFree:
        return '\$4.99';
      case ProductType.adFreePlus20Imports:
        return '\$6.99';
      case ProductType.adFreePlus50Generations:
        return '\$9.99';
      case ProductType.ultimateBundle:
        return '\$11.99';

      // Subscriptions
      case ProductType.monthlyPremium:
        return '\$5.99/month';
      case ProductType.yearlyPremium:
        return '\$34.99/year';
    }
  }
}

/// Constants for product IDs
class ProductIds {
  // Consumables
  static const String recipeImports10 = 'recipease_imports_10'; // Quick pack
  static const String recipeImports20 = 'recipease_imports_20';
  static const String recipeGenerations50 = 'recipease_generations_50';

  // Non-consumables
  static const String adFree = 'recipease_ad_free';
  static const String adFreePlus20Imports = 'recipease_ad_free_imports_20';
  static const String adFreePlus50Generations =
      'recipease_ad_free_generations_50';
  static const String ultimateBundle = 'recipease_ultimate_bundle';

  // Subscriptions
  static const String monthlyPremium = 'recipease_premium_monthly';
  static const String yearlyPremium = 'recipease_premium_yearly';

  /// Get all product IDs as a set
  static Set<String> get allProductIds => {
    recipeImports10,
    recipeImports20,
    recipeGenerations50,
    adFree,
    adFreePlus20Imports,
    adFreePlus50Generations,
    ultimateBundle,
    monthlyPremium,
    yearlyPremium,
  };

  /// Get product type from ID
  static ProductType? getProductType(String id) {
    switch (id) {
      case recipeImports10:
        return ProductType.recipeImports10;
      case recipeImports20:
        return ProductType.recipeImports20;
      case recipeGenerations50:
        return ProductType.recipeGenerations50;
      case adFree:
        return ProductType.adFree;
      case adFreePlus20Imports:
        return ProductType.adFreePlus20Imports;
      case adFreePlus50Generations:
        return ProductType.adFreePlus50Generations;
      case ultimateBundle:
        return ProductType.ultimateBundle;
      case monthlyPremium:
        return ProductType.monthlyPremium;
      case yearlyPremium:
        return ProductType.yearlyPremium;
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
      id: ProductIds.recipeImports10,
      title: 'Quick Import Pack',
      description:
          'Import 10 recipes from any cooking website. Perfect for trying the feature!',
      productType: ProductType.recipeImports10,
      purchaseType: PurchaseType.consumable,
      creditAmount: 10,
      icon: Icons.rocket_launch,
    ),
    PurchaseProduct(
      id: ProductIds.recipeImports20,
      title: '20 Recipe Imports',
      description:
          'Import 20 recipes from Instagram, TikTok, YouTube, AllRecipes, and thousands more sites',
      productType: ProductType.recipeImports20,
      purchaseType: PurchaseType.consumable,
      creditAmount: 20,
      icon: Icons.share,
    ),
    PurchaseProduct(
      id: ProductIds.recipeGenerations50,
      title: '50 Recipe Generations',
      description:
          'Generate 50 custom recipes based on your ingredients and preferences',
      productType: ProductType.recipeGenerations50,
      purchaseType: PurchaseType.consumable,
      creditAmount: 50,
      icon: Icons.auto_awesome,
    ),

    // Non-consumables
    PurchaseProduct(
      id: ProductIds.adFree,
      title: 'RecipEase Ad-Free',
      description:
          'Remove all ads permanently. Clean, distraction-free cooking experience forever',
      productType: ProductType.adFree,
      purchaseType: PurchaseType.nonConsumable,
      includesAdFree: true,
      icon: Icons.block,
    ),
    PurchaseProduct(
      id: ProductIds.adFreePlus20Imports,
      title: 'Ad-Free + Import Starter',
      description:
          'Remove ads FOREVER + get 20 recipe imports. Perfect way to get started!',
      productType: ProductType.adFreePlus20Imports,
      purchaseType: PurchaseType.nonConsumable,
      creditAmount: 20,
      includesAdFree: true,
      icon: Icons.card_giftcard,
    ),
    PurchaseProduct(
      id: ProductIds.adFreePlus50Generations,
      title: 'Ad-Free + Recipe Pack',
      description:
          'Remove ads FOREVER + generate 50 recipes. Perfect for creative cooks!',
      productType: ProductType.adFreePlus50Generations,
      purchaseType: PurchaseType.nonConsumable,
      creditAmount: 50,
      includesAdFree: true,
      icon: Icons.palette,
    ),
    PurchaseProduct(
      id: ProductIds.ultimateBundle,
      title: 'Ultimate RecipEase Bundle',
      description:
          'Remove ads forever + 30 recipe imports + 50 recipe generations. Everything you need!',
      productType: ProductType.ultimateBundle,
      purchaseType: PurchaseType.nonConsumable,
      creditAmount: 80, // 30 + 50
      includesAdFree: true,
      isBestValue: true,
      icon: Icons.local_fire_department,
    ),

    // Subscriptions
    PurchaseProduct(
      id: ProductIds.monthlyPremium,
      title: 'RecipEase Premium - Monthly',
      description:
          'No ads + 25 recipe imports + 20 recipe generations every month. 7-day free trial!',
      productType: ProductType.monthlyPremium,
      purchaseType: PurchaseType.subscription,
      monthlyCredits: 45, // 25 + 20
      includesAdFree: true,
      icon: Icons.workspace_premium,
    ),
    PurchaseProduct(
      id: ProductIds.yearlyPremium,
      title: 'RecipEase Premium - Yearly',
      description:
          'SAVE 50%! No ads + 35 imports + 30 recipe generations/month. Only \$2.92/month. 7-day free trial!',
      productType: ProductType.yearlyPremium,
      purchaseType: PurchaseType.subscription,
      monthlyCredits: 65, // 35 + 30
      includesAdFree: true,
      isBestValue: true,
      icon: Icons.star_rounded,
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
