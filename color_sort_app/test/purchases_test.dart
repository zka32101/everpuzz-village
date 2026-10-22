import 'package:color_sort_app/game/app_state.dart';
import 'package:color_sort_app/game/purchases.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/foundation.dart';

import 'helpers.dart';

class FakePurchases implements PurchaseGate {
  BuyStatus status = BuyStatus.success;
  String? nextTx = 'tx1';
  bool owned = false;
  final Set<String> ownedIds = {};

  @override
  Future<Map<String, String>> prices(Iterable<String> ids) async =>
      {for (final id in ids) id: '¥${id.length * 100}'};

  @override
  Future<BuyResult> buy(String productId) async {
    if (status != BuyStatus.success) return BuyResult(status);
    if (productId == 'ads_removal') owned = true;
    if (productId.endsWith('_pack_1')) ownedIds.add(productId);
    return BuyResult(BuyStatus.success,
        transactionId: nextTx, adsRemoved: owned);
  }

  @override
  Future<bool> restore() async => owned;

  @override
  Future<bool> adsRemoved() async => owned;

  @override
  Future<Set<String>> ownedProducts() async =>
      {...ownedIds, if (owned) 'ads_removal'};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('窓口が無ければ店は出ない', () async {
    final app = await loadApp();
    expect(app.shopAvailable, isFalse);
    expect(await app.buyProduct('coins_small'), isFalse);
  });

  test('コインパックは付与され、同じ取引IDでは二重に付与されない', () async {
    final gate = FakePurchases();
    final app = await loadApp(purchaseGate: gate);
    final before = app.coins;
    expect(await app.buyProduct('coins_small'), isTrue);
    expect(app.coins, before + 300);
    expect(await app.buyProduct('coins_small'), isFalse); // 同じ tx1
    expect(app.coins, before + 300);
    gate.nextTx = 'tx2';
    expect(await app.buyProduct('coins_medium'), isTrue);
    expect(app.coins, before + 300 + 800);
  });

  test('取消・失敗・取引IDなしでは付与しない', () async {
    final gate = FakePurchases();
    final app = await loadApp(purchaseGate: gate);
    final before = app.coins;
    gate.status = BuyStatus.cancelled;
    expect(await app.buyProduct('coins_small'), isFalse);
    gate.status = BuyStatus.failed;
    expect(await app.buyProduct('coins_small'), isFalse);
    gate.status = BuyStatus.success;
    gate.nextTx = null;
    expect(await app.buyProduct('coins_small'), isFalse);
    expect(app.coins, before);
  });

  test('広告削除でライフ切れでも遊べ、ライフも減らない。再起動後も保持', () async {
    final kv = MemoryKeyValueStore();
    final gate = FakePurchases();
    final app = await loadApp(kv: kv, purchaseGate: gate);
    for (var i = 0; i < economyConfig.maxLives; i++) {
      await app.loseLife();
    }
    expect(app.canPlay, isFalse);
    expect(await app.buyProduct('ads_removal'), isTrue);
    expect(app.adsRemoved, isTrue);
    expect(app.canPlay, isTrue);
    expect(await app.loseLife(), isFalse);

    gate.owned = false; // ストアに繋がらない状態を想定しても保存値は…
    final again =
        await loadApp(kv: kv, purchaseGate: FakePurchases()..owned = true);
    expect(again.adsRemoved, isTrue);
  });

  test('返金などでストア側の権利が無ければ起動時に外れる', () async {
    final kv = MemoryKeyValueStore();
    final app = await loadApp(kv: kv, purchaseGate: FakePurchases());
    await app.buyProduct('ads_removal');
    final again = await loadApp(kv: kv, purchaseGate: FakePurchases());
    expect(again.adsRemoved, isFalse);
  });

  test('購入の復元', () async {
    final gate = FakePurchases()..owned = true;
    final app = await loadApp(purchaseGate: gate);
    expect(await app.restorePurchases(), isTrue);
    expect(app.adsRemoved, isTrue);
  });

  test('素材のない商品(enabled:false)は店に出ず、買えない', () async {
    final app = await loadApp(purchaseGate: FakePurchases());
    expect(app.shopProducts.map((p) => p.id), isNot(contains('deco_pack_1')));
    expect(await app.buyProduct('deco_pack_1'), isFalse);
    expect(app.owns('deco.seasonal1'), isFalse);
  });

  test('ライフ全回復: 満タンまで戻る。同じ取引IDは二重に効かない', () async {
    final app = await loadApp(purchaseGate: FakePurchases());
    for (var i = 0; i < 5; i++) {
      await app.loseLife();
    }
    expect(app.lives, economyConfig.maxLives - 5);
    expect(await app.buyProduct('life_refill'), isTrue);
    expect(app.lives, economyConfig.maxLives);
    expect(await app.buyProduct('life_refill'), isFalse); // 同じ tx1
  });

  test('買い切り(unlock)は中身が使え、復元で戻り、再購入できない', () async {
    final catalog = ShopCatalog.fromJson('''
{"entitlement":"ads_removed","products":[
 {"id":"deco_pack_1","kind":"unlock","grants":["deco.a","deco.b"]},
 {"id":"starter_pack","kind":"starterPack","coins":500,"grants":["deco.s"]}]}''');
    final gate = FakePurchases();
    final app = await loadApp(purchaseGate: gate, catalogOverride: catalog);
    expect(app.owns('deco.a'), isFalse);
    expect(await app.buyProduct('deco_pack_1'), isTrue);
    expect(app.owns('deco.a') && app.owns('deco.b'), isTrue);
    expect(await app.buyProduct('deco_pack_1'), isFalse);

    // 別端末: 保存が空でも、ストアの所有から復元できる
    final other = await loadApp(purchaseGate: gate, catalogOverride: catalog);
    expect(other.owns('deco.a'), isTrue);
  });

  test('スターターパックは1回だけ。コインと中身が付く', () async {
    final catalog = ShopCatalog.fromJson('''
{"entitlement":"ads_removed","products":[
 {"id":"starter_pack","kind":"starterPack","coins":500,"grants":["deco.s"]}]}''');
    final gate = FakePurchases();
    final app = await loadApp(purchaseGate: gate, catalogOverride: catalog);
    final before = app.coins;
    expect(await app.buyProduct('starter_pack'), isTrue);
    expect(app.coins, before + 500);
    expect(app.owns('deco.s'), isTrue);
    gate.nextTx = 'tx9';
    expect(await app.buyProduct('starter_pack'), isFalse); // 使用済み
    expect(app.coins, before + 500);
  });

  testWidgets('店の画面から購入できる(価格が出る)', (tester) async {
    final app =
        await tester.runAsync(() => loadApp(purchaseGate: FakePurchases()));
    await tester.pumpWidget(appWidget(app!));
    await tester.tap(find.byKey(const Key('menu-shop')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('product_coins_small')), findsOneWidget);
    final before = app.coins;
    await tester.tap(find.descendant(
        of: find.byKey(const Key('product_coins_small')),
        matching: find.byType(FilledButton)));
    await tester.pumpAndSettle();
    expect(app.coins, before + 300);
  });
}
