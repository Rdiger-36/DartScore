import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages in-app donation purchases and the resulting "supporter" status.
///
/// Wraps the `in_app_purchase` plugin: loads the consumable donation products,
/// starts purchases, listens to the purchase stream, and persists whether the
/// user has ever donated. Donations are consumables but supporter status is
/// sticky once granted.
class DonationProvider extends ChangeNotifier {
  static const _supporterKey = 'is_supporter';

  /// Store product ids for the available donation tiers.
  static const Set<String> productIds = {
    'donation_coffee',
    'donation_beer',
    'donation_pizza',
  };

  bool _isSupporter = false;
  bool _thankYouPending = false;
  bool _loading = false;
  bool _available = false;
  List<ProductDetails> _products = [];
  String? _errorMessage;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// Whether the user has donated at least once (persisted).
  bool get isSupporter => _isSupporter;

  /// Whether a thank-you message should be shown after a successful purchase.
  bool get thankYouPending => _thankYouPending;

  /// Whether product details are currently being loaded from the store.
  bool get loading => _loading;

  /// Whether in-app purchases are available on this device/store.
  bool get available => _available;

  /// The loaded donation products, sorted cheapest-first.
  List<ProductDetails> get products => _products;

  /// The last purchase error message, or null if none.
  String? get errorMessage => _errorMessage;

  /// Creates the provider and asynchronously initializes the purchase flow.
  DonationProvider() {
    _init();
  }

  /// Loads persisted supporter status, checks store availability, subscribes to
  /// the purchase stream, and fetches product details.
  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _isSupporter = prefs.getBool(_supporterKey) ?? false;
    notifyListeners();

    _available = await InAppPurchase.instance.isAvailable();
    if (!_available) {
      notifyListeners();
      return;
    }

    _sub = InAppPurchase.instance.purchaseStream.listen(
      _onPurchases,
      onDone: () => _sub?.cancel(),
    );

    await _loadProducts();
  }

  /// Queries the store for the donation [productIds] and sorts them by price.
  Future<void> _loadProducts() async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();

    final response =
        await InAppPurchase.instance.queryProductDetails(productIds);
    _products = List.of(response.productDetails)
      ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
    _loading = false;
    notifyListeners();
  }

  /// Starts a consumable purchase for the given donation [product].
  Future<void> buy(ProductDetails product) async {
    _errorMessage = null;
    notifyListeners();
    await InAppPurchase.instance.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
  }

  /// Handles purchase-stream updates: completes pending purchases, grants
  /// supporter status on success/restore, and surfaces errors.
  void _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(p);
      }
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _markSupporter();
        case PurchaseStatus.error:
          _errorMessage = p.error?.message;
          notifyListeners();
        case PurchaseStatus.pending:
        case PurchaseStatus.canceled:
          break;
      }
    }
  }

  /// Marks the user as a supporter, flags a pending thank-you, and persists it.
  Future<void> _markSupporter() async {
    _isSupporter = true;
    _thankYouPending = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_supporterKey, true);
    notifyListeners();
  }

  /// Clears the pending thank-you flag after the message has been shown.
  void clearThankYou() {
    _thankYouPending = false;
    notifyListeners();
  }

  /// Cancels the purchase-stream subscription.
  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
