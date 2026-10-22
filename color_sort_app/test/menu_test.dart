import 'package:color_sort_app/game/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/foundation.dart';
import 'package:puzzle_core/meta.dart';

import 'helpers.dart';
import 'purchases_test.dart' show FakePurchases;

Future<AppState> appWith(WidgetTester tester,
    {MemoryKeyValueStore? kv, bool shop = false, int coins = 0}) async {
  final store = kv ?? MemoryKeyValueStore();
  if (coins > 0) {
    final clock = FakeClock(DateTime.utc(2026, 1, 1, 12));
    await VersionedJsonStore(store).save(
        AppState.economyKey,
        AppState.economySchema,
        EconomyState.initial(economyConfig, clock.now())
            .copyWith(coins: coins)
            .toJson());
  }
  return (await tester.runAsync(
      () => loadApp(kv: store, purchaseGate: shop ? FakePurchases() : null)))!;
}

void main() {
  testWidgets('標準のメニュー: 設定・情報。ショップは課金の窓口がある時だけ', (tester) async {
    final off = await appWith(tester);
    await tester.pumpWidget(appWidget(off, town: true));
    expect(find.byKey(const Key('menu-shop')), findsNothing);
    expect(find.byKey(const Key('menu-settings')), findsOneWidget);
    expect(find.byKey(const Key('menu-info')), findsOneWidget);

    final on = await appWith(tester, shop: true);
    await tester.pumpWidget(appWidget(on, town: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('menu-shop')), findsOneWidget);
    // 並びは ショップ → 設定 → 情報
    final xs = [
      for (final k in ['menu-shop', 'menu-settings', 'menu-info'])
        tester.getCenter(find.byKey(Key(k))).dx,
    ];
    expect(xs, [...xs]..sort());
  });

  testWidgets('設定: 言語を選ぶとすぐ反映され、保存される', (tester) async {
    final kv = MemoryKeyValueStore();
    final app = await appWith(tester, kv: kv);
    await tester.pumpWidget(appWidget(app, town: true)); // 端末は英語
    await tester.tap(find.byKey(const Key('menu-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsWidgets);
    await tester.tap(find.byKey(const Key('languageDropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日本語').last);
    await tester.pumpAndSettle();
    expect(find.text('設定'), findsWidgets); // 日本語に切り替わった
    expect(app.settings.languageOverride, 'ja');
    final saved = await tester.runAsync(() => SettingsStore(kv).load());
    expect(saved!.languageOverride, 'ja');
  });

  testWidgets('設定: 動きを減らすを切り替えると保存される。購入の復元はショップがある時だけ', (tester) async {
    final kv = MemoryKeyValueStore();
    final app = await appWith(tester, kv: kv);
    await tester.pumpWidget(appWidget(app, town: true));
    await tester.tap(find.byKey(const Key('menu-settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('setting-restore')), findsNothing);
    await tester.tap(find.byKey(const Key('setting-reduceMotion')));
    await tester.pumpAndSettle();
    expect(app.settings.reduceMotion, isTrue);
    expect(
        (await tester.runAsync(() => SettingsStore(kv).load()))!.reduceMotion,
        isTrue);

    final shop = await appWith(tester, shop: true);
    await tester.pumpWidget(const SizedBox()); // 別のアプリとして作り直す
    await tester.pumpWidget(appWidget(shop, town: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('menu-settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('setting-restore')), findsOneWidget);
  });

  testWidgets('設定: データ削除は確認を挟み、進行・コイン・町が消える(設定は残る)', (tester) async {
    final app = await appWith(tester, coins: 100);
    await tester.runAsync(() => app.placeBuilding('small_house', 0));
    await tester.runAsync(() => app.recordWin(0, moves: 10, stars: 2));
    await tester.runAsync(
        () => app.updateSettings(app.settings.copyWith(reduceMotion: true)));
    expect(app.coins, greaterThan(0));
    await tester.pumpWidget(appWidget(app, town: true));
    await tester.tap(find.byKey(const Key('menu-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('setting-delete')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('deleteDialog')), findsOneWidget);
    // やめる → 何も消えない
    await tester.tap(find.byKey(const Key('deleteCancel')));
    await tester.pumpAndSettle();
    expect(app.townState.placements, isNotEmpty);
    // 削除する
    await tester.tap(find.byKey(const Key('setting-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deleteConfirm')));
    await tester.pumpAndSettle();
    expect(app.coins, 0);
    expect(app.townState.placements, isEmpty);
    expect(app.clearedLevels, 0);
    expect(app.settings.reduceMotion, isTrue);
  });

  testWidgets('情報: クレジット(AI画像の表記を含む)が出る。URL・版が無ければその項目は出ない', (tester) async {
    final app = await appWith(tester);
    await tester.pumpWidget(appWidget(app, town: true));
    await tester.tap(find.byKey(const Key('menu-info')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('info-credits')), findsOneWidget);
    expect(find.textContaining('AI'), findsWidgets);
    expect(find.byKey(const Key('info-version')), findsNothing);
    expect(find.byKey(const Key('info-privacy')), findsNothing);
  });
}
