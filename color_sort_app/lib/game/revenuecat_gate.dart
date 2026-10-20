import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'purchases.dart';

/// RevenueCat の実装。公開SDKキーをビルド時に渡したときだけ使う
/// (`--dart-define=RC_API_KEY=...`。キーはリポジトリに入れない)。
class RevenueCatGate implements PurchaseGate {
  RevenueCatGate._(this._entitlement);

  final String _entitlement;

  static Future<RevenueCatGate> configure(
    String apiKey, {
    required String entitlement,
  }) async {
    await Purchases.configure(PurchasesConfiguration(apiKey));
    return RevenueCatGate._(entitlement);
  }

  bool _has(CustomerInfo info) =>
      info.entitlements.active.containsKey(_entitlement);

  @override
  Future<Map<String, String>> prices(Iterable<String> productIds) async {
    final found = await Purchases.getProducts(productIds.toList());
    return {for (final p in found) p.identifier: p.priceString};
  }

  @override
  Future<BuyResult> buy(String productId) async {
    try {
      final found = await Purchases.getProducts([productId]);
      if (found.isEmpty) return const BuyResult(BuyStatus.failed);
      final result =
          await Purchases.purchase(PurchaseParams.storeProduct(found.first));
      return BuyResult(
        BuyStatus.success,
        transactionId: result.storeTransaction.transactionIdentifier,
        adsRemoved: _has(result.customerInfo),
      );
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      return BuyResult(code == PurchasesErrorCode.purchaseCancelledError
          ? BuyStatus.cancelled
          : BuyStatus.failed);
    }
  }

  @override
  Future<bool> restore() async => _has(await Purchases.restorePurchases());

  @override
  Future<bool> adsRemoved() async => _has(await Purchases.getCustomerInfo());
}
