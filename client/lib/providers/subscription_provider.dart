import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class SubscriptionProvider with ChangeNotifier {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<ProductDetails> _products = [];
  bool _isLoading = false;
  bool _isPremium = false;
  String? _error;

  // Getters
  List<ProductDetails> get products => _products;
  bool get isLoading => _isLoading;
  bool get isPremium => _isPremium;
  String? get error => _error;

  // Product IDs
  static const String _monthlySubscription = 'recipease_premium_monthly';
  static const String _yearlySubscription = 'recipease_premium_yearly';
  static const String _lifetimePurchase = 'recipease_premium_lifetime';

  SubscriptionProvider() {
    _initialize();
  }

  // Public method to reinitialize subscriptions
  Future<void> reinitialize() async {
    _error = null;
    await _initialize();
  }

  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Initialize the in-app purchase
      final bool available = await _inAppPurchase.isAvailable();
      if (!available) {
        _error = 'Store not available';
        return;
      }

      // Load products
      final ProductDetailsResponse response = await _inAppPurchase
          .queryProductDetails({
            _monthlySubscription,
            _yearlySubscription,
            _lifetimePurchase,
          });

      if (response.notFoundIDs.isNotEmpty) {
        _error = 'Some products not found: ${response.notFoundIDs.join(", ")}';
      }

      _products = response.productDetails;

      // Check current subscription status
      await _checkSubscriptionStatus();

      // Listen to purchase updates
      _inAppPurchase.purchaseStream.listen(
        _handlePurchaseUpdate,
        onDone: () {},
        onError: (error) {
          _error = error.toString();
          notifyListeners();
        },
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _checkSubscriptionStatus() async {
    if (_auth.currentUser == null) return;

    try {
      final userDoc =
          await _firestore
              .collection('users')
              .doc(_auth.currentUser!.uid)
              .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        _isPremium = data['isPremium'] ?? false;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> purchase(ProductDetails product) async {
    try {
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product,
      );

      if (product.id == _lifetimePurchase) {
        await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        await _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> _handlePurchaseUpdate(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _isLoading = true;
      } else {
        _isLoading = false;
        if (purchaseDetails.status == PurchaseStatus.error) {
          _error = purchaseDetails.error?.message;
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          await _verifyAndDeliverProduct(purchaseDetails);
        }
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
    notifyListeners();
  }

  Future<void> _verifyAndDeliverProduct(PurchaseDetails purchaseDetails) async {
    if (_auth.currentUser == null) return;

    try {
      // Verify the purchase with your backend
      final verificationData = {
        'productId': purchaseDetails.productID,
        'purchaseToken':
            purchaseDetails.verificationData.serverVerificationData,
        'platform': defaultTargetPlatform.toString(),
      };

      // Update user's premium status in Firestore
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'isPremium': true,
        'premiumSince': FieldValue.serverTimestamp(),
        'lastPurchase': verificationData,
      });

      _isPremium = true;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> restorePurchases() async {
    try {
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
