import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/purchase_product.dart';
import '../services/purchase_service.dart';
import '../services/credits_service.dart';

class SubscriptionProvider with ChangeNotifier {
  final PurchaseService _purchaseService = PurchaseService();
  final CreditsService _creditsService = CreditsService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<PurchaseProduct> _products = [];
  Map<String, int> _credits = {'recipeImports': 0, 'recipeGenerations': 0};
  bool _isLoading = false;
  bool _isPremium = false;
  bool _hasActiveSubscription = false;
  bool _trialActive = false;
  bool _trialUsed = false;
  DateTime? _trialEndAt;
  bool _unlimitedUsage = false;
  String? _subscriptionType;
  String? _error;

  // Getters
  List<PurchaseProduct> get products => _products;
  Map<String, int> get credits => _credits;
  bool get isLoading => _isLoading;
  bool get isPremium => _isPremium;
  bool get hasActiveSubscription => _hasActiveSubscription;
  bool get trialActive => _trialActive;
  bool get eligibleForTrial => !_hasActiveSubscription && !_trialActive && !_trialUsed;
  DateTime? get trialEndAt => _trialEndAt;
  bool get unlimitedUsage => _unlimitedUsage;
  String? get subscriptionType => _subscriptionType;
  String? get error => _error;

  // Get products by type
  List<PurchaseProduct> get consumables =>
      _products
          .where((p) => p.purchaseType == PurchaseType.consumable)
          .toList();
  List<PurchaseProduct> get nonConsumables =>
      _products
          .where((p) => p.purchaseType == PurchaseType.nonConsumable)
          .toList();
  List<PurchaseProduct> get subscriptions =>
      _products
          .where((p) => p.purchaseType == PurchaseType.subscription)
          .toList();

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
      // Initialize the purchase service
      final bool success = await _purchaseService.initialize();
      if (!success) {
        _error = 'Store not available';
        return;
      }

      // Load products
      _products = _purchaseService.availableProducts;

      // Check current subscription status
      await _checkSubscriptionStatus();

      // Load credits
      await _loadCredits();

      // Listen to purchase and product updates
      _purchaseService.productsStream.listen((products) {
        _products = products;
        notifyListeners();
      });

      _purchaseService.purchaseStateStream.listen((isLoading) {
        _isLoading = isLoading;
        notifyListeners();
      });
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCredits() async {
    try {
      _credits = await _creditsService.getCreditBalance();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading credits: $e');
    }
  }

  Future<void> _checkSubscriptionStatus() async {
    if (_auth.currentUser == null) return;

    try {
      final userRef = _firestore.collection('users').doc(_auth.currentUser!.uid);
      final userDoc = await userRef.get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        _isPremium = data['isPremium'] ?? false;
        _hasActiveSubscription = data['subscriptionActive'] ?? false;
        _trialActive = data['trialActive'] ?? false;
        _trialUsed = data['trialUsed'] ?? false;
        _subscriptionType = data['subscriptionType'];
        final Timestamp? trialEndAtTs = data['trialEndAt'];
        _trialEndAt = trialEndAtTs?.toDate();
        _unlimitedUsage = data['unlimitedUsage'] ?? false;
        // If trial ended, grant full monthly credits once and flip to non-trial
        if (_hasActiveSubscription && _trialActive && trialEndAtTs != null) {
          final DateTime trialEnd = trialEndAtTs.toDate();
          if (DateTime.now().isAfter(trialEnd)) {
            // Determine full monthly credit amounts based on plan
            final bool isMonthly =
                _subscriptionType == 'recipease_premium_monthly';
            final int importCredits = isMonthly ? 25 : 35;
            final int generationCredits = isMonthly ? 20 : 30;

            await _creditsService.addCredits(
              recipeImports: importCredits,
              recipeGenerations: generationCredits,
              reason: 'Subscription trial ended - first month credits',
            );

            await userRef.update({
              'trialActive': false,
              'lastSubscriptionRenewal': FieldValue.serverTimestamp(),
            });
            _trialActive = false;
            _trialEndAt = null;
          }
        }
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Refresh all data
  Future<void> refreshData() async {
    await _checkSubscriptionStatus();
    await _loadCredits();
  }

  Future<void> purchase(PurchaseProduct product) async {
    try {
      _isLoading = true;
      notifyListeners();

      final success = await _purchaseService.purchaseProduct(product);

      if (success) {
        // Wait a moment for the purchase to process
        await Future.delayed(const Duration(seconds: 2));

        // Refresh data
        await refreshData();
      } else {
        _error = 'Purchase failed';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _purchaseService.restorePurchases();

      // Wait a moment for purchases to process
      await Future.delayed(const Duration(seconds: 2));

      // Refresh data
      await refreshData();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Check if user has enough credits for an action
  Future<bool> hasEnoughCredits(CreditType type, {int amount = 1}) async {
    // Unlimited usage for: unlimited subscriptions OR active trials
    if (_unlimitedUsage || _trialActive) return true;
    return await _creditsService.hasEnoughCredits(type: type, amount: amount);
  }

  /// Use credits for an action
  Future<bool> useCredits(
    CreditType type, {
    int amount = 1,
    String? reason,
  }) async {
    // Unlimited usage for: unlimited subscriptions OR active trials
    if (_unlimitedUsage || _trialActive) {
      await _loadCredits();
      return true;
    }
    final success = await _creditsService.useCredits(
      type: type,
      amount: amount,
      reason: reason,
    );

    if (success) {
      await _loadCredits();
    }

    return success;
  }

  /// Check if a product is already subscribed
  bool isProductSubscribed(PurchaseProduct product) {
    if (!_hasActiveSubscription || _subscriptionType == null) {
      return false;
    }

    // Subscription type is stored as the product ID
    return _subscriptionType == product.id;
  }

  @override
  void dispose() {
    _purchaseService.dispose();
    super.dispose();
  }
}
