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

      // Log what the store returned
      debugPrint(
        '[IAP] Store query: products=${response.productDetails.length}, notFound=${response.notFoundIDs.length}',
      );

      // Prefer store-backed details whenever available; avoid dev fallback unless nothing loads
      final Map<String, ProductDetails> byId = {
        for (final d in response.productDetails) d.id: d,
      };

      final storeBacked =
          ProductConfigurations.allProducts
              .where((p) => byId.containsKey(p.id))
              .map((p) => p.copyWith(productDetails: byId[p.id]))
              .toList();

      // Coverage computation removed (no longer needed for logging)

      if (storeBacked.isNotEmpty) {
        debugPrint('[IAP] Using store-backed products: ${storeBacked.length}');
        _availableProducts = storeBacked;
        _productsController.add(_availableProducts);
      } else {
        // Development fallback (no products returned). Prices may be mock values.
        debugPrint(
          '[IAP] No store-backed products found. Falling back to local configuration.',
        );
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

    // Use the same verification flow to prevent duplicate deliveries
    await _verifyAndDeliverPurchase(mockPurchaseDetails);
  }

  /// Purchase a product
  Future<bool> purchaseProduct(PurchaseProduct product) async {
    if (product.productDetails == null) {
      // If ProductDetails are missing, only simulate in debug builds.
      if (kDebugMode) {
        await _simulatePurchase(product);
        return true;
      }
      debugPrint(
        'Cannot purchase ${product.id}: missing ProductDetails from the store. '
        'Ensure product IDs exist in App Store Connect/Play Console and that '
        'queryProductDetails() returns them on device.',
      );
      return false;
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
      // Migrate old product IDs to new ones for backward compatibility
      final migratedProductId = ProductIds.migrateProductId(
        purchaseDetails.productID,
      );
      
      // Get product configuration using migrated ID
      final productConfig = ProductConfigurations.getProductById(
        migratedProductId,
      );
      
      if (productConfig == null) {
        debugPrint(
          'Product configuration not found: ${purchaseDetails.productID} (migrated to: $migratedProductId)',
        );
        return;
      }
      
      // Log migration if product ID was changed
      if (migratedProductId != purchaseDetails.productID) {
        debugPrint(
          '🔄 Migrated old product ID "${purchaseDetails.productID}" to "$migratedProductId"',
        );
      }

      // Check if this purchase has already been processed
      final purchaseRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('purchases')
          .doc(purchaseDetails.purchaseID);

      final purchaseDoc = await purchaseRef.get();
      if (purchaseDoc.exists) {
        final data = purchaseDoc.data();
        final bool benefitsDelivered = data?['benefitsDelivered'] ?? false;
        
        if (benefitsDelivered) {
          debugPrint(
            'Purchase ${purchaseDetails.purchaseID} already processed, skipping benefit delivery',
          );
          return;
        }
      }

      // Verify purchase with backend (simplified version)
      // In production, you should verify with your backend server.
      // NOTE: Apple recommends verifying the receipt with the App Store to confirm validity
      // and checking for 'Sandbox receipt used in production' (error 21007) to handle test environments.
      // Currently, this implementation trusts the client-side transaction and syncs to Firestore.
      final verificationData = {
        'productId': purchaseDetails.productID,
        'purchaseId': purchaseDetails.purchaseID,
        'verificationData':
            purchaseDetails.verificationData.serverVerificationData,
        'source': purchaseDetails.verificationData.source,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': Platform.isIOS ? 'ios' : 'android',
        'benefitsDelivered': false,
      };

      // Save purchase to Firestore
      await purchaseRef.set(verificationData, SetOptions(merge: true));

      // Deliver the purchase benefits
      await _deliverPurchaseBenefits(productConfig, purchaseDetails);

      // Mark benefits as delivered
      await purchaseRef.update({'benefitsDelivered': true});

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

        // Check if this is the first time enabling subscription (no prior sub/trial)
        final bool hasActiveSub =
            (data?['subscriptionActive'] ?? false) == true;
        // Check both current active trial AND history of trial usage
        final bool hasTrial = (data?['trialActive'] ?? false) == true;
        final bool trialUsed = (data?['trialUsed'] ?? false) == true;

        // If user is eligible for a trial (no active sub, no active trial, never used trial)
        // Note: In production, StoreKit handles the actual billing trial.
        // This logic ensures the app's UI reflects the trial status.
        // Ensure 'Introductory Offer' is configured in App Store Connect.
        if (!hasActiveSub && !hasTrial && !trialUsed) {
          // Mark trial active and set end timestamp (7 days from now)
          updates['trialActive'] = true;
          updates['trialUsed'] = true;
          updates['trialEndAt'] = Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 7)),
          );

          if (kDebugMode) {
            debugPrint('✨ Trial activated: Unlimited usage for 7 days');
          }
        } else {
          // If upgrading or re-subscribing, ensure trial is cleared
          updates['trialActive'] = false;
        }

        // Unlimited tier: enable unlimitedUsage
        if (product.productType == ProductType.unlimitedPremium ||
            product.unlimitedUsage) {
          updates['unlimitedUsage'] = true;
        }
      }

      // Handle one-time credits (consumables and non-consumables with credits)
      if (product.creditAmount != null &&
          product.purchaseType != PurchaseType.subscription) {
        // For bundles and one-time purchases, distribute credits
        final int importCredits;
        final int generationCredits;

        switch (product.productType) {
          case ProductType.recipeImports15:
            importCredits = 15;
            generationCredits = 0;
            break;
          case ProductType.recipeImports25:
            importCredits = 25;
            generationCredits = 0;
            break;
          case ProductType.recipeGenerations25:
            importCredits = 0;
            generationCredits = 25;
            break;
          case ProductType.adFreePlus25Imports:
            importCredits = 25;
            generationCredits = 0;
            break;
          case ProductType.adFreePlus25Generations:
            importCredits = 0;
            generationCredits = 25;
            break;
          case ProductType.ultimateBundle:
            importCredits = 25;
            generationCredits = 25;
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
