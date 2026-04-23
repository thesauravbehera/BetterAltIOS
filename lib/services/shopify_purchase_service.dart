import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Service that checks Fat Burner purchase status via a secure
/// Firebase Cloud Function instead of calling Shopify directly.
/// The Shopify API token never leaves the server.
class ShopifyPurchaseService {
  ShopifyPurchaseService._();
  static final ShopifyPurchaseService instance = ShopifyPurchaseService._();

  final _functions = FirebaseFunctions.instance;

  /// Checks if the user has purchased "Fat Burner" by calling the
  /// `checkFatBurnerPurchase` Cloud Function.
  Future<bool> hasPurchasedFatBurner({
    String? email,
    String? phone,
  }) async {
    if ((email == null || email.trim().isEmpty) &&
        (phone == null || phone.trim().isEmpty)) {
      throw ArgumentError('Provide at least one of: email, phone');
    }

    try {
      final callable = _functions.httpsCallable('checkFatBurnerPurchase');
      final result = await callable.call<Map<String, dynamic>>({
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      });

      final purchased = result.data['purchased'] as bool? ?? false;
      debugPrint('ShopifyPurchaseService: Cloud Function returned purchased=$purchased');
      return purchased;
    } catch (e) {
      debugPrint('ShopifyPurchaseService: Cloud Function error: $e');
      rethrow;
    }
  }
}
