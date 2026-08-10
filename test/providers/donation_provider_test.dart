import 'dart:async';

import 'package:dartscore_app/providers/donation_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A store that answers instantly and writes down what it was asked.
///
/// The point of most of these tests is what is *not* on [calls] after the app
/// has started, so the stand-in records rather than verifies.
class _FakeStore extends InAppPurchasePlatform with MockPlatformInterfaceMixin {
  final List<String> calls = [];
  final purchases = StreamController<List<PurchaseDetails>>.broadcast();

  /// What [queryProductDetails] hands back.
  List<ProductDetails> products = const [];

  /// What [isAvailable] answers.
  bool availability = true;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream {
    calls.add('purchaseStream');
    return purchases.stream;
  }

  @override
  Future<bool> isAvailable() async {
    calls.add('isAvailable');
    return availability;
  }

  @override
  Future<ProductDetailsResponse> queryProductDetails(
      Set<String> identifiers) async {
    calls.add('queryProductDetails');
    return ProductDetailsResponse(
        productDetails: products, notFoundIDs: const []);
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    calls.add('completePurchase');
  }
}

/// A donation tier as the store would describe it.
ProductDetails _product(String id, double price) => ProductDetails(
      id: id,
      title: id,
      description: id,
      price: '$price',
      rawPrice: price,
      currencyCode: 'EUR',
    );

/// A purchase the store reports back, paid for and still to be completed.
PurchaseDetails _purchase() => PurchaseDetails(
      productID: 'donation_coffee',
      verificationData: PurchaseVerificationData(
          localVerificationData: '',
          serverVerificationData: '',
          source: 'test'),
      transactionDate: null,
      status: PurchaseStatus.purchased,
    )..pendingCompletePurchase = true;

/// The provider loads from shared_preferences in its constructor, so a test
/// that read it straight away would see the default.
Future<DonationProvider> _created() async {
  final provider = DonationProvider();
  await Future<void>.delayed(Duration.zero);
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeStore store;

  setUp(() {
    // InAppPurchase.instance registers the real Android or StoreKit platform
    // on first access, depending on defaultTargetPlatform, which would put the
    // stand-in straight back out again and reach for a method channel that is
    // not there. A platform with no store keeps the fake in place.
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    store = _FakeStore();
    InAppPurchasePlatform.instance = store;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('starting the app', () {
    test('asks the store for nothing', () async {
      await _created();

      // The prices are a network round trip, and availability a connection to
      // the billing service. Neither belongs on a launch where nobody goes
      // near the donation screen.
      expect(store.calls, isNot(contains('isAvailable')));
      expect(store.calls, isNot(contains('queryProductDetails')));
    });

    test('still listens for purchases', () async {
      await _created();

      // A purchase that was never completed last session arrives on the next
      // subscription and only then, so this one cannot wait for the screen.
      expect(store.calls, contains('purchaseStream'));
    });

    test('reads the supporter flag without the store', () async {
      SharedPreferences.setMockInitialValues({'is_supporter': true});

      final provider = await _created();

      expect(provider.isSupporter, isTrue);
      expect(store.calls, isNot(contains('isAvailable')));
    });

    test('credits a purchase that arrives before the screen is ever opened',
        () async {
      final provider = await _created();

      store.purchases.add([_purchase()]);
      await Future<void>.delayed(Duration.zero);

      expect(provider.isSupporter, isTrue);
      expect(provider.thankYouPending, isTrue);
      expect(store.calls, contains('completePurchase'));
    });
  });

  group('opening the donation screen', () {
    test('is what fetches the prices', () async {
      store.products = [_product('donation_coffee', 1.99)];
      final provider = await _created();

      await provider.connectToStore();

      expect(store.calls, contains('isAvailable'));
      expect(store.calls, contains('queryProductDetails'));
      expect(provider.products.map((p) => p.id), ['donation_coffee']);
      expect(provider.loading, isFalse);
    });

    test('sorts the tiers cheapest first', () async {
      store.products = [
        _product('donation_pizza', 9.99),
        _product('donation_coffee', 1.99),
        _product('donation_beer', 4.99),
      ];
      final provider = await _created();

      await provider.connectToStore();

      expect(provider.products.map((p) => p.id),
          ['donation_coffee', 'donation_beer', 'donation_pizza']);
    });

    test('asks the store once however often the screen is reopened', () async {
      final provider = await _created();

      await provider.connectToStore();
      await provider.connectToStore();

      expect(store.calls.where((c) => c == 'queryProductDetails'), hasLength(1));
    });

    test('does not ask for prices a store that is not there can not give',
        () async {
      store.availability = false;
      final provider = await _created();

      await provider.connectToStore();

      expect(provider.available, isFalse);
      expect(provider.loading, isFalse);
      expect(store.calls, isNot(contains('queryProductDetails')));
    });

    test('leaves loading set before the first frame of the screen', () async {
      final provider = await _created();

      // Not awaited: this is the state the screen's first build reads, and it
      // has to be the spinner rather than "no donations available".
      final pending = provider.connectToStore();

      expect(provider.loading, isTrue);
      await pending;
    });
  });
}
