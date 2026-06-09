import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DonationProvider extends ChangeNotifier {
  static const _supporterKey = 'is_supporter';

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

  bool get isSupporter => _isSupporter;
  bool get thankYouPending => _thankYouPending;
  bool get loading => _loading;
  bool get available => _available;
  List<ProductDetails> get products => _products;
  String? get errorMessage => _errorMessage;

  DonationProvider() {
    _init();
  }

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

  Future<void> buy(ProductDetails product) async {
    _errorMessage = null;
    notifyListeners();
    await InAppPurchase.instance.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
  }

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

  Future<void> _markSupporter() async {
    _isSupporter = true;
    _thankYouPending = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_supporterKey, true);
    notifyListeners();
  }

  void clearThankYou() {
    _thankYouPending = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
