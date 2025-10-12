import 'package:in_app_purchase/in_app_purchase.dart';

/// Enum for different types of purchases
enum PurchaseType { consumable, nonConsumable, subscription }

/// Enum for specific product types
enum ProductType {
  // Consumables
  recipeImports20,
  recipeGenerations50,

  // Non-consumables
  adFree,
  adFreePlus20Imports,
  adFreePlus50Generations,
  ultimateBundle, // Ad-free + 20 imports + 50 generations
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
    );
  }

  String get price => productDetails?.price ?? 'N/A';
}

/// Constants for product IDs
class ProductIds {
  // Consumables
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
      id: ProductIds.recipeImports20,
      title: '20 Recipe Imports',
      description: 'Import 20 recipes from your favorite websites',
      productType: ProductType.recipeImports20,
      purchaseType: PurchaseType.consumable,
      creditAmount: 20,
    ),
    PurchaseProduct(
      id: ProductIds.recipeGenerations50,
      title: '50 Recipe Generations',
      description: 'Generate 50 AI-powered recipes',
      productType: ProductType.recipeGenerations50,
      purchaseType: PurchaseType.consumable,
      creditAmount: 50,
    ),

    // Non-consumables
    PurchaseProduct(
      id: ProductIds.adFree,
      title: 'Ad-Free Experience',
      description: 'Remove all ads permanently',
      productType: ProductType.adFree,
      purchaseType: PurchaseType.nonConsumable,
      includesAdFree: true,
    ),
    PurchaseProduct(
      id: ProductIds.adFreePlus20Imports,
      title: 'Ad-Free + 20 Imports',
      description: 'Remove ads forever and get 20 recipe imports',
      productType: ProductType.adFreePlus20Imports,
      purchaseType: PurchaseType.nonConsumable,
      creditAmount: 20,
      includesAdFree: true,
    ),
    PurchaseProduct(
      id: ProductIds.adFreePlus50Generations,
      title: 'Ad-Free + 50 Generations',
      description: 'Remove ads forever and get 50 recipe generations',
      productType: ProductType.adFreePlus50Generations,
      purchaseType: PurchaseType.nonConsumable,
      creditAmount: 50,
      includesAdFree: true,
    ),
    PurchaseProduct(
      id: ProductIds.ultimateBundle,
      title: 'Ultimate Bundle',
      description: 'Ad-free + 20 imports + 50 generations',
      productType: ProductType.ultimateBundle,
      purchaseType: PurchaseType.nonConsumable,
      creditAmount: 70, // 20 + 50
      includesAdFree: true,
      isBestValue: true,
    ),

    // Subscriptions
    PurchaseProduct(
      id: ProductIds.monthlyPremium,
      title: 'Monthly Premium',
      description: 'Ad-free + 10 imports + 25 generations per month',
      productType: ProductType.monthlyPremium,
      purchaseType: PurchaseType.subscription,
      monthlyCredits: 35, // 10 + 25
      includesAdFree: true,
    ),
    PurchaseProduct(
      id: ProductIds.yearlyPremium,
      title: 'Yearly Premium',
      description: 'Ad-free + 15 imports + 40 generations per month',
      productType: ProductType.yearlyPremium,
      purchaseType: PurchaseType.subscription,
      monthlyCredits: 55, // 15 + 40
      includesAdFree: true,
      isBestValue: true,
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
