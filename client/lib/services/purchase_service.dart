import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../models/purchase_product.dart';
import 'credits_service.dart';

/// Mock PurchaseDetails for development/testing
class MockPurchaseDetails extends PurchaseDetails {
  MockPurchaseDetails(String productId)
    : super(
        productID: productId,
        transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
        status: PurchaseStatus.purchased,
        verificationData: PurchaseVerificationData(
          localVerificationData: 'mock_verification_data',
          serverVerificationData: 'mock_server_verification_data',
          source: 'mock_source',
        ),
      );
}

/// Service for managing in-app purchases
class PurchaseService {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CreditsService _creditsService = CreditsService();

  late StreamSubscription<List<PurchaseDetails>> _subscription;
  final StreamController<List<PurchaseProduct>> _productsController =
      StreamController<List<PurchaseProduct>>.broadcast();
  final StreamController<bool> _purchaseStateController =
      StreamController<bool>.broadcast();

  List<PurchaseProduct> _availableProducts = [];
  bool _isInitialized = false;

  Stream<List<PurchaseProduct>> get productsStream =>
      _productsController.stream;
  Stream<bool> get purchaseStateStream => _purchaseStateController.stream;
  List<PurchaseProduct> get availableProducts => _availableProducts;
  bool get isInitialized => _isInitialized;

  /// Initialize the purchase service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Check if the store is available
      final bool available = await _inAppPurchase.isAvailable();
      if (!available) {
        debugPrint('Store is not available');
        return false;
      }

      // Listen to purchase updates
      _subscription = _inAppPurchase.purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: () => _subscription.cancel(),
        onError: (error) => debugPrint('Purchase stream error: $error'),
      );

      // Load products
      await loadProducts();

      // Restore previous purchases
      await restorePurchases();

      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Error initializing purchase service: $e');
      return false;
    }
  }

  /// Load available products from the store
  Future<void> loadProducts() async {
    try {
      final ProductDetailsResponse response = await _inAppPurchase
          .queryProductDetails(ProductIds.allProductIds);

      // Verbose store logging removed

      // Prefer store-backed details whenever available; avoid dev fallback unless nothing loads
      final Map<String, ProductDetails> byId = {
        for (final d in response.productDetails) d.id: d,
      };

      final storeBacked = ProductConfigurations.allProducts
          .where((p) => byId.containsKey(p.id))
          .map((p) => p.copyWith(productDetails: byId[p.id]))
          .toList();

      // Coverage computation removed (no longer needed for logging)

      if (storeBacked.isNotEmpty) {
        _availableProducts = storeBacked;
        _productsController.add(_availableProducts);
      } else {
        // Development fallback (no products returned). Prices may be mock values.
        _availableProducts = ProductConfigurations.allProducts;
        _productsController.add(_availableProducts);
      }
    } catch (e) {
      debugPrint('Error loading products: $e');
      // For development/testing, show products even if there's an error
      _availableProducts = ProductConfigurations.allProducts;
      _productsController.add(_availableProducts);
      // Verbose fallback logging removed
    }
  }

  /// Simulate a purchase for development/testing
  Future<void> _simulatePurchase(PurchaseProduct product) async {
    // Verbose simulation logging removed

    // Simulate purchase delay
    await Future.delayed(const Duration(seconds: 1));

    // Create mock purchase details for development
    final mockPurchaseDetails = MockPurchaseDetails(product.id);

    // Deliver the purchase benefits
    await _deliverPurchaseBenefits(product, mockPurchaseDetails);
  }

  /// Purchase a product
  Future<bool> purchaseProduct(PurchaseProduct product) async {
    if (product.productDetails == null) {
      // Verbose missing details logging removed
      // For development, simulate a successful purchase
      await _simulatePurchase(product);
      return true;
    }

    try {
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product.productDetails!,
      );

      bool success = false;

      switch (product.purchaseType) {
        case PurchaseType.consumable:
          success = await _inAppPurchase.buyConsumable(
            purchaseParam: purchaseParam,
          );
          break;
        case PurchaseType.nonConsumable:
          success = await _inAppPurchase.buyNonConsumable(
            purchaseParam: purchaseParam,
          );
          break;
        case PurchaseType.subscription:
          success = await _inAppPurchase.buyNonConsumable(
            purchaseParam: purchaseParam,
          );
          break;
      }

      return success;
    } catch (e) {
      debugPrint('Error purchasing product: $e');
      return false;
    }
  }

  /// Handle purchase updates
  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      // Verbose status logging removed

      if (purchaseDetails.status == PurchaseStatus.pending) {
        _purchaseStateController.add(true); // Loading
      } else {
        _purchaseStateController.add(false); // Not loading

        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('Purchase error: ${purchaseDetails.error}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          await _verifyAndDeliverPurchase(purchaseDetails);
        }

        // Complete the purchase
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  /// Verify and deliver the purchase
  Future<void> _verifyAndDeliverPurchase(
    PurchaseDetails purchaseDetails,
  ) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      debugPrint('User not authenticated');
      return;
    }

    try {
      // Get product configuration
      final productConfig = ProductConfigurations.getProductById(
        purchaseDetails.productID,
      );
      if (productConfig == null) {
        debugPrint('Product configuration not found: ${purchaseDetails.productID}');
        return;
      }

      // Verify purchase with backend (simplified version)
      // In production, you should verify with your backend server
      final verificationData = {
        'productId': purchaseDetails.productID,
        'purchaseId': purchaseDetails.purchaseID,
        'verificationData':
            purchaseDetails.verificationData.serverVerificationData,
        'source': purchaseDetails.verificationData.source,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': Platform.isIOS ? 'ios' : 'android',
      };

      // Save purchase to Firestore
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('purchases')
          .doc(purchaseDetails.purchaseID)
          .set(verificationData, SetOptions(merge: true));

      // Deliver the purchase benefits
      await _deliverPurchaseBenefits(productConfig, purchaseDetails);

      // Verbose success logging removed
    } catch (e) {
      debugPrint('Error verifying purchase: $e');
      rethrow;
    }
  }

  /// Deliver purchase benefits to the user
  Future<void> _deliverPurchaseBenefits(
    PurchaseProduct product,
    PurchaseDetails purchaseDetails,
  ) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      // Update user document with purchase info
      final Map<String, dynamic> updates = {};
      // Load current user state to determine trial status
      final userRef = _firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();
      final data = userDoc.data();

      // Handle ad-free
      if (product.includesAdFree) {
        updates['isPremium'] = true;
        updates['premiumSince'] = FieldValue.serverTimestamp();
      }

      // Handle subscriptions
      if (product.purchaseType == PurchaseType.subscription) {
        updates['subscriptionActive'] = true;
        updates['subscriptionType'] = product.id;
        updates['subscriptionStartDate'] = FieldValue.serverTimestamp();

        // Unlimited tier: enable unlimitedUsage, no trials or credits
        if (product.productType == ProductType.unlimitedPremium || product.unlimitedUsage) {
          updates['unlimitedUsage'] = true;
          // If user had an active trial, end it immediately
          updates['trialActive'] = false;
        } else {
        // If this is the first time enabling subscription (no prior sub/trial),
        // start a 7-day trial and grant capped trial credits (total 12).
        final bool hasActiveSub = (data?['subscriptionActive'] ?? false) == true;
        final bool hasTrial = (data?['trialActive'] ?? false) == true;
        if (!hasActiveSub && !hasTrial) {
          // Mark trial active and set end timestamp (7 days from now)
          updates['trialActive'] = true;
          updates['trialUsed'] = true;
          updates['trialEndAt'] = Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 7)),
          );

          // Grant capped trial credits: 12 total → 7 imports + 5 generations
          await _creditsService.addCredits(
            recipeImports: 7,
            recipeGenerations: 5,
            reason: 'Subscription trial start: ${product.title}',
          );
        }
        }
      }

      // Handle one-time credits (consumables and non-consumables with credits)
      if (product.creditAmount != null &&
          product.purchaseType != PurchaseType.subscription) {
        // For bundles and one-time purchases, distribute credits
        final int importCredits;
        final int generationCredits;

        switch (product.productType) {
          case ProductType.recipeImports10:
            importCredits = 10;
            generationCredits = 0;
            break;
          case ProductType.recipeImports20:
            importCredits = 20;
            generationCredits = 0;
            break;
          case ProductType.recipeGenerations50:
            importCredits = 0;
            generationCredits = 50;
            break;
          case ProductType.adFreePlus20Imports:
            importCredits = 20;
            generationCredits = 0;
            break;
          case ProductType.adFreePlus50Generations:
            importCredits = 0;
            generationCredits = 50;
            break;
          case ProductType.ultimateBundle:
            importCredits = 30;
            generationCredits = 50;
            break;
          default:
            importCredits = 0;
            generationCredits = 0;
        }

        await _creditsService.addCredits(
          recipeImports: importCredits,
          recipeGenerations: generationCredits,
          reason: 'Purchase: ${product.title}',
        );
      }

      // Update user document
      if (updates.isNotEmpty) {
        await userRef.update(updates);
      }

      // Verbose benefits delivered logging removed
    } catch (e) {
      debugPrint('Error delivering purchase benefits: $e');
      rethrow;
    }
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    try {
      await _inAppPurchase.restorePurchases();
      // Verbose restore logging removed
    } catch (e) {
      debugPrint('Error restoring purchases: $e');
      rethrow;
    }
  }

  /// Check if user has active subscription
  Future<bool> hasActiveSubscription() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final data = userDoc.data();
      return data?['subscriptionActive'] ?? false;
    } catch (e) {
      debugPrint('Error checking subscription: $e');
      return false;
    }
  }

  /// Check if user has ad-free (either non-consumable or subscription)
  Future<bool> hasAdFree() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final data = userDoc.data();
      return data?['isPremium'] ?? false;
    } catch (e) {
      debugPrint('Error checking ad-free status: $e');
      return false;
    }
  }

  /// Get products by type
  List<PurchaseProduct> getProductsByType(PurchaseType type) {
    return _availableProducts
        .where((product) => product.purchaseType == type)
        .toList();
  }

  /// Dispose of the service
  void dispose() {
    _subscription.cancel();
    _productsController.close();
    _purchaseStateController.close();
  }
}
