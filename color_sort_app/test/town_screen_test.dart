import 'package:color_sort_app/game/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/foundation.dart';

import 'helpers.dart';

Future<AppState> appWithCoins(WidgetTester tester, int coins) async {
  final kv = MemoryKeyValueStore();
  final clock = FakeClock(DateTime.utc(2026, 1, 1, 12));
  await VersionedJsonStore(kv).save(
    AppState.economyKey,
    AppState.economySchema,
    EconomyState.initial(economyConfig, clock.now())
        .copyWith(coins: coins)
        .toJson(),
  );
  return (await tester.runAsync(() => loadApp(kv: kv, clock: clock)))!;
}

void main() {
  townMetaTests();
  testWidgets('起動すると町。最初は5マス(解放1+4)で、あそぶ/面を選ぶがある', (tester) async {
    final app = await appWithCoins(tester, 0);
    await tester.pumpWidget(appWidget(app, town: true));
    expect(find.byKey(const Key('townGrid')), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(Key('cell-$i')), findsOneWidget);
    }
    expect(find.byKey(const Key('cell-5')), findsNothing);
    expect(find.byKey(const Key('play')), findsOneWidget);
    await tester.tap(find.byKey(const Key('chooseLevel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('level-0')), findsOneWidget);
  });

  testWidgets('あそぶで次の面に入る', (tester) async {
    final app = await appWithCoins(tester, 0);
    await tester.pumpWidget(appWidget(app, town: true));
    await tester.tap(find.byKey(const Key('play')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tube-0')), findsOneWidget);
  });

  testWidgets('置く→育てる→動かす。コインが減り、状態が保存される', (tester) async {
    final app = await appWithCoins(tester, 100);
    await tester.pumpWidget(appWidget(app, town: true));

    await tester.tap(find.byKey(const Key('cell-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('place_small_house')));
    await tester.pumpAndSettle();
    expect(app.coins, 85);
    expect(find.text('Small house'), findsWidgets);

    await tester.tap(find.byKey(const Key('cell-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('upgrade')));
    await tester.pumpAndSettle();
    expect(app.coins, 60);
    expect(app.townState.placementOf('small_house')!.stage, 2);

    await tester.tap(find.byKey(const Key('cell-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('move')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('moveBanner')), findsOneWidget);
    await tester.tap(find.byKey(const Key('cell-3')));
    await tester.pumpAndSettle();
    expect(app.townState.placementOf('small_house')!.cell, 3);
    expect(app.coins, 60); // 動かすのは無料
    expect(find.byKey(const Key('moveBanner')), findsNothing);
  });

  testWidgets('コイン不足では置けない(選択肢が押せない)', (tester) async {
    final app = await appWithCoins(tester, 10);
    await tester.pumpWidget(appWidget(app, town: true));
    await tester.tap(find.byKey(const Key('cell-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('place_small_house')));
    await tester.pumpAndSettle();
    expect(app.townState.placements, isEmpty);
    expect(app.coins, 10);
  });

  testWidgets('ライフ0でも町は操作でき、あそぶは案内を出す', (tester) async {
    final app = await appWithCoins(tester, 50);
    for (var i = 0; i < economyConfig.maxLives; i++) {
      await tester.runAsync(app.loseLife);
    }
    await tester.pumpWidget(appWidget(app, town: true));
    await tester.tap(find.byKey(const Key('cell-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('place_small_house')));
    await tester.pumpAndSettle();
    expect(app.townState.placements, hasLength(1));
    await tester.tap(find.byKey(const Key('play')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('noLives')), findsOneWidget);
    // 時刻で示す(「あと◯分」とは言わない)
    expect(find.textContaining('around'), findsWidgets);
  });

  testWidgets('再起動しても町が残る', (tester) async {
    final kv = MemoryKeyValueStore();
    final clock = FakeClock(DateTime.utc(2026, 1, 1, 12));
    await VersionedJsonStore(kv).save(
        AppState.economyKey,
        AppState.economySchema,
        EconomyState.initial(economyConfig, clock.now())
            .copyWith(coins: 100)
            .toJson());
    final app = (await tester.runAsync(() => loadApp(kv: kv, clock: clock)))!;
    await tester.runAsync(() => app.placeBuilding('small_house', 2));
    final again = (await tester.runAsync(() => loadApp(kv: kv, clock: clock)))!;
    expect(again.townState.placementOf('small_house')!.cell, 2);
    expect(again.coins, 85);
  });

  testWidgets('日本語・文字200%でも崩れない', (tester) async {
    final app = await appWithCoins(tester, 100);
    await tester.runAsync(() => app.placeBuilding('small_house', 0));
    await tester
        .pumpWidget(appWidget(app, town: true, lang: 'ja', textScale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('ちいさなおうち'), findsWidgets);
  });
}

void townMetaTests() {
  testWidgets('贈り物は1日1回受け取れ、日付が変わると再び受け取れる', (tester) async {
    final kv = MemoryKeyValueStore();
    final clock = FakeClock(DateTime.utc(2026, 1, 1, 12));
    final app = (await tester.runAsync(() => loadApp(kv: kv, clock: clock)))!;
    await tester.pumpWidget(appWidget(app, town: true));
    expect(find.byKey(const Key('gift')), findsOneWidget);
    final before = app.coins;
    await tester.tap(find.byKey(const Key('claimGift')));
    await tester.pumpAndSettle();
    expect(app.coins, before + app.townConfig.dailyGift);
    expect(find.byKey(const Key('gift')), findsNothing);
    clock.advance(const Duration(days: 3)); // 連続しなくても受け取れる
    await tester.pumpWidget(appWidget(app, town: true, lang: 'ja'));
    await tester.pumpAndSettle();
    expect(app.canClaimGift, isTrue);
  });

  testWidgets('新しい建物は静かに知らせ、OKで消える', (tester) async {
    final app = await appWithCoins(tester, 0);
    await tester.pumpWidget(appWidget(app, town: true));
    expect(find.byKey(const Key('newBuilding')), findsNothing);
    // 3面クリア済みの進行にする
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => app.recordWin(i, moves: 10, stars: 1));
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('newBuilding')), findsOneWidget);
    expect(find.textContaining('Mushroom house'), findsWidgets);
    await tester.tap(find.descendant(
        of: find.byKey(const Key('newBuilding')),
        matching: find.byType(TextButton)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('newBuilding')), findsNothing);
  });

  testWidgets('こびとは合計段階6ごとに1人', (tester) async {
    final app = await appWithCoins(tester, 1000);
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => app.recordWin(i, moves: 10, stars: 1));
    }
    await tester.runAsync(() => app.placeBuilding('small_house', 0));
    await tester.runAsync(() => app.upgradeBuilding('small_house'));
    await tester.runAsync(() => app.upgradeBuilding('small_house'));
    expect(app.dwellers, 0); // 合計3
    await tester.runAsync(() => app.placeBuilding('mushroom_house', 1));
    await tester.runAsync(() => app.upgradeBuilding('mushroom_house'));
    await tester.runAsync(() => app.upgradeBuilding('mushroom_house'));
    expect(app.dwellers, 1); // 合計6
    await tester.pumpWidget(appWidget(app, town: true));
    expect(find.byKey(const Key('dwellers')), findsOneWidget);
  });

  testWidgets('20種そろうと完成の知らせが1回だけ出る', (tester) async {
    final app = await appWithCoins(tester, 5000);
    for (var i = 0; i < 57; i++) {
      await tester.runAsync(() => app.recordWin(i, moves: 10, stars: 1));
    }
    final ids = app.townConfig.buildings.map((b) => b.id).toList();
    for (var i = 0; i < ids.length; i++) {
      await tester.runAsync(() => app.placeBuilding(ids[i], i));
    }
    expect(app.pendingTownMilestone, 'complete');
    await tester.pumpWidget(appWidget(app, town: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('milestone_complete')), findsOneWidget);
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('milestone_complete')), findsNothing);
    expect(app.pendingTownMilestone, isNull);
  });
}
