import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Types of credits
enum CreditType { recipeImport, recipeGeneration }

/// Service for managing user credits
class CreditsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user's credits document reference
  DocumentReference? get _userCreditsRef {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('credits')
        .doc('balance');
  }

  /// Initialize credits for a new user
  Future<void> initializeCredits() async {
    if (_userCreditsRef == null) return;

    try {
      await _userCreditsRef!.set({
        'recipeImports': 0,
        'recipeGenerations': 0,
        'totalRecipeImports': 0,
        'totalRecipeGenerations': 0,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error initializing credits: $e');
      rethrow;
    }
  }

  /// Get current credit balance
  Future<Map<String, int>> getCreditBalance() async {
    if (_userCreditsRef == null) {
      return {'recipeImports': 0, 'recipeGenerations': 0};
    }

    try {
      final doc = await _userCreditsRef!.get();
      if (!doc.exists) {
        await initializeCredits();
        return {'recipeImports': 0, 'recipeGenerations': 0};
      }

      final data = doc.data() as Map<String, dynamic>;
      return {
        'recipeImports': data['recipeImports'] ?? 0,
        'recipeGenerations': data['recipeGenerations'] ?? 0,
      };
    } catch (e) {
      debugPrint('Error getting credit balance: $e');
      return {'recipeImports': 0, 'recipeGenerations': 0};
    }
  }

  /// Add credits
  Future<void> addCredits({
    int recipeImports = 0,
    int recipeGenerations = 0,
    String? reason,
  }) async {
    if (_userCreditsRef == null) return;

    try {
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(_userCreditsRef!);

        int currentImports = 0;
        int currentGenerations = 0;
        int totalImports = 0;
        int totalGenerations = 0;

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          currentImports = data['recipeImports'] ?? 0;
          currentGenerations = data['recipeGenerations'] ?? 0;
          totalImports = data['totalRecipeImports'] ?? 0;
          totalGenerations = data['totalRecipeGenerations'] ?? 0;
        }

        transaction.set(_userCreditsRef!, {
          'recipeImports': currentImports + recipeImports,
          'recipeGenerations': currentGenerations + recipeGenerations,
          'totalRecipeImports': totalImports + recipeImports,
          'totalRecipeGenerations': totalGenerations + recipeGenerations,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Log the transaction
        if (reason != null) {
          await _logCreditTransaction(
            transaction: transaction,
            recipeImports: recipeImports,
            recipeGenerations: recipeGenerations,
            reason: reason,
            isAddition: true,
          );
        }
      });

      debugPrint(
        'Credits added: $recipeImports imports, $recipeGenerations generations',
      );
    } catch (e) {
      debugPrint('Error adding credits: $e');
      rethrow;
    }
  }

  /// Use credits (deduct)
  Future<bool> useCredits({
    required CreditType type,
    int amount = 1,
    String? reason,
  }) async {
    if (_userCreditsRef == null) return false;

    try {
      bool success = false;

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(_userCreditsRef!);

        if (!doc.exists) {
          await initializeCredits();
          throw Exception('Insufficient credits');
        }

        final data = doc.data() as Map<String, dynamic>;

        final String fieldName =
            type == CreditType.recipeImport
                ? 'recipeImports'
                : 'recipeGenerations';

        final int currentBalance = data[fieldName] ?? 0;

        if (currentBalance < amount) {
          throw Exception(
            'Insufficient credits: need $amount, have $currentBalance',
          );
        }

        transaction.update(_userCreditsRef!, {
          fieldName: currentBalance - amount,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // Log the transaction
        await _logCreditTransaction(
          transaction: transaction,
          recipeImports: type == CreditType.recipeImport ? amount : 0,
          recipeGenerations: type == CreditType.recipeGeneration ? amount : 0,
          reason: reason ?? 'Credit used',
          isAddition: false,
        );

        success = true;
      });

      if (success) {
        debugPrint('Credits used: $amount ${type.toString()}');
      }

      return success;
    } catch (e) {
      debugPrint('Error using credits: $e');
      return false;
    }
  }

  /// Check if user has enough credits
  Future<bool> hasEnoughCredits({
    required CreditType type,
    int amount = 1,
  }) async {
    final balance = await getCreditBalance();
    final fieldName =
        type == CreditType.recipeImport ? 'recipeImports' : 'recipeGenerations';

    return (balance[fieldName] ?? 0) >= amount;
  }

  /// Get credit history
  Future<List<Map<String, dynamic>>> getCreditHistory({int limit = 50}) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    try {
      final querySnapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('credits')
              .doc('transactions')
              .collection('history')
              .orderBy('timestamp', descending: true)
              .limit(limit)
              .get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      debugPrint('Error getting credit history: $e');
      return [];
    }
  }

  /// Log credit transaction
  Future<void> _logCreditTransaction({
    required Transaction transaction,
    required int recipeImports,
    required int recipeGenerations,
    required String reason,
    required bool isAddition,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final transactionRef =
        _firestore
            .collection('users')
            .doc(userId)
            .collection('credits')
            .doc('transactions')
            .collection('history')
            .doc();

    transaction.set(transactionRef, {
      'recipeImports': recipeImports,
      'recipeGenerations': recipeGenerations,
      'reason': reason,
      'type': isAddition ? 'addition' : 'deduction',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Grant monthly subscription credits
  Future<void> grantMonthlySubscriptionCredits({
    required int importCredits,
    required int generationCredits,
  }) async {
    await addCredits(
      recipeImports: importCredits,
      recipeGenerations: generationCredits,
      reason: 'Monthly subscription renewal',
    );
  }

  /// Handle subscription renewal
  Future<void> handleSubscriptionRenewal({
    required String subscriptionId,
    required int importCredits,
    required int generationCredits,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      // Check last renewal date
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final data = userDoc.data();

      if (data != null && data.containsKey('lastSubscriptionRenewal')) {
        final lastRenewal =
            (data['lastSubscriptionRenewal'] as Timestamp).toDate();
        final now = DateTime.now();

        // If less than 25 days since last renewal, don't grant credits yet
        if (now.difference(lastRenewal).inDays < 25) {
          debugPrint('Subscription credits already granted this month');
          return;
        }
      }

      // Grant credits
      await addCredits(
        recipeImports: importCredits,
        recipeGenerations: generationCredits,
        reason: 'Subscription renewal: $subscriptionId',
      );

      // Update last renewal date
      await _firestore.collection('users').doc(userId).update({
        'lastSubscriptionRenewal': FieldValue.serverTimestamp(),
      });

      debugPrint('Monthly subscription credits granted');
    } catch (e) {
      debugPrint('Error handling subscription renewal: $e');
      rethrow;
    }
  }
}
