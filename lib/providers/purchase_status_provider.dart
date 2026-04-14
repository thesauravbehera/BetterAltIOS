import 'package:flutter/foundation.dart';
import 'package:fat_burner/services/shopify_purchase_service.dart';

/// Holds purchase status (Fat Burner) in app state.
/// Handles loading, errors, and result.
class PurchaseStatusProvider extends ChangeNotifier {
  PurchaseStatusProvider._();
  static final PurchaseStatusProvider instance = PurchaseStatusProvider._();

  final _purchaseService = ShopifyPurchaseService.instance;

  bool _isLoading = false;
  String? _error;
  bool? _hasPurchased;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool? get hasPurchased => _hasPurchased;

  /// True when we have a result (success or failure from API).
  bool get hasResult => _hasPurchased != null && _error == null;

  /// Clears error and optionally result.
  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  /// Checks purchase status. Pass email and/or phone from current user.
  Future<void> checkPurchase({String? email, String? phone}) async {
    if ((email == null || email.trim().isEmpty) &&
        (phone == null || phone.trim().isEmpty)) {
      _error = 'Email or phone required to check purchase';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _hasPurchased = await _purchaseService.hasPurchasedFatBurner(
        email: email?.trim().isEmpty == true ? null : email?.trim(),
        phone: phone?.trim().isEmpty == true ? null : phone?.trim(),
      );
      _error = null;
    } on ArgumentError catch (e) {
      _error = e.message ?? 'Invalid input';
      _hasPurchased = null;
    } catch (e) {
      _error = 'Unable to verify purchase. Please try again.';
      _hasPurchased = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    _isLoading = false;
    _error = null;
    _hasPurchased = null;
    notifyListeners();
  }
}
