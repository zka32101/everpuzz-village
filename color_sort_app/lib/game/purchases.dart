import 'dart:convert';

/// 商品の種類。コインパックは消費型、広告削除は買い切り(権利)。
enum ProductKind { adsRemoval, coinPack }

/// 商品の定義(価格はストアから取る。ここは「何が付くか」だけ)。
class ShopProduct {
  const ShopProduct({required this.id, required this.kind, this.coins = 0});

  /// ストア側の商品ID(RevenueCat の Product identifier と同じにする)。
  final String id;
  final ProductKind kind;

  /// コインパックで付与するコイン。
  final int coins;
}

/// 商品カタログ(`assets/shop/products.json`)。
class ShopCatalog {
  const ShopCatalog({required this.entitlement, required this.products});

  static const empty = ShopCatalog(entitlement: '', products: []);

  /// 広告削除の権利ID(RevenueCat の Entitlement identifier)。
  final String entitlement;
  final List<ShopProduct> products;

  factory ShopCatalog.fromJson(String raw) {
    final map = jsonDecode(raw) as Map<String, Object?>;
    final list = (map['products'] as List).cast<Map<String, Object?>>();
    return ShopCatalog(
      entitlement: map['entitlement'] as String,
      products: [
        for (final p in list)
          ShopProduct(
            id: p['id'] as String,
            kind: ProductKind.values.byName(p['kind'] as String),
            coins: (p['coins'] as int?) ?? 0,
          ),
      ],
    );
  }

  ShopProduct? byId(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }
}

enum BuyStatus { success, cancelled, failed }

/// 購入の結果。[transactionId] はコインの二重付与防止に使う。
class BuyResult {
  const BuyResult(this.status, {this.transactionId, this.adsRemoved = false});

  final BuyStatus status;
  final String? transactionId;

  /// 購入後の「広告削除の権利」の有無。
  final bool adsRemoved;
}

/// 課金の窓口。実体(RevenueCat)は鍵があるときだけ差し込む。
abstract interface class PurchaseGate {
  /// 商品IDごとの表示用価格(ストアの通貨表記)。取れない商品は含めない。
  Future<Map<String, String>> prices(Iterable<String> productIds);

  Future<BuyResult> buy(String productId);

  /// 購入の復元。復元後に広告削除の権利があるか。
  Future<bool> restore();

  /// 現在、広告削除の権利があるか。
  Future<bool> adsRemoved();
}
