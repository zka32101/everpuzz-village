import 'package:color_sort_app/game/app_state.dart';
import 'package:color_sort_app/game/art.dart';
import 'package:color_sort_app/l10n/strings.dart';
import 'package:color_sort_app/ui/play_screen.dart';
import 'package:color_sort_app/ui/town_walk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  seasonTests();
  walkerTests();
  stageArtTests();
  realArtTests();
  artTests();
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

void artTests() {
  testWidgets('画像が配置されていれば建物は画像で描き、無ければ図形+名前のまま', (tester) async {
    final app = await appWithCoins(tester, 100);
    await tester.runAsync(() => app.placeBuilding('small_house', 0));
    await tester.pumpWidget(appWidget(app, town: true));
    // 画像なし: 文字で代用(名前が見える)
    expect(find.text('Small house'), findsWidgets);
    expect(find.byType(Image), findsNothing);

    final withArt = AppState(
      pack: app.pack,
      kv: MemoryKeyValueStore(),
      progress: app.progress,
      economyState:
          EconomyState.initial(economyConfig, DateTime.utc(2026, 1, 1, 12)),
      townConfig: app.townConfig,
      townState: app.townState,
      art: const ArtCatalog({'small_house_s1'}),
    );
    await tester.pumpWidget(appWidget(withArt, town: true));
    await tester.pump();
    expect(find.byKey(const Key('art-small_house_s1')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // 名前・段階は画像でも文字(Semantics)で示す
    expect(find.bySemanticsLabel(RegExp('Small house')), findsWidgets);
  });
}

void realArtTests() {
  testWidgets('同梱の画像(63枚)が読め、容器の画像描画でも崩れない', (tester) async {
    final art = (await tester.runAsync(() => ArtCatalog.load(rootBundle)))!;
    expect(
        art.has('bg_stage_01') && art.has('tube_back') && art.has('tube_front'),
        isTrue);
    expect(art.has('small_house_s1') && art.has('rainbow_arch_s3'), isTrue);
    final real = (await tester.runAsync(() => loadApp()))!;
    final app = AppState(
      pack: real.pack,
      kv: real.kv,
      progress: real.progress,
      economyState: real.current,
      townConfig: real.townConfig,
      art: art,
    );
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(L10n(
      translator: translatorFor('en'),
      child: MaterialApp(home: PlayScreen(app: app, index: 40)),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('tube-0')), findsOneWidget);
    await tester.tap(find.byKey(const Key('tube-0')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

void stageArtTests() {
  test('ステージ背景は12面ごとに切り替わり、無い段階は手前の段階で代用する', () {
    const all = ArtCatalog({
      'bg_stage_01',
      'bg_stage_02',
      'bg_stage_03',
      'bg_stage_04',
      'bg_stage_05',
    });
    expect(all.stageBackground(0), 'bg_stage_01');
    expect(all.stageBackground(11), 'bg_stage_01');
    expect(all.stageBackground(12), 'bg_stage_02');
    expect(all.stageBackground(59), 'bg_stage_05');
    expect(all.stageBackground(60), 'bg_stage_01'); // 巡る
    expect(all.stageBackground(999), 'bg_stage_04');
    const some = ArtCatalog({'bg_stage_01', 'bg_stage_03'});
    expect(some.stageBackground(14), 'bg_stage_01'); // 02 が無い
    expect(some.stageBackground(30), 'bg_stage_03');
    expect(ArtCatalog.empty.stageBackground(0), isNull);
  });
}

void walkerTests() {
  test('こびとの歩き: 範囲内・決まった動き・立ち止まる・ずれて出発', () {
    const walk = DwellerWalk(columns: 4, cells: 9);
    for (var i = 0; i < 10; i++) {
      for (var s = 0.0; s < 200; s += 0.7) {
        final p = walk.position(i, s);
        expect(p.dx, inInclusiveRange(0.5 - 1e-9, 3.5 + 1e-9)); // 列 0〜3 の中心の間
        expect(p.dy, inInclusiveRange(0.5 - 1e-9, 2.5 + 1e-9)); // 9マス=3行
      }
    }
    // 同じ入力なら同じ位置(再描画しても飛ばない)
    expect(walk.position(2, 12.3), walk.position(2, 12.3));
    // 立ち止まっている間は動かない(歩く8秒+止まる3秒)
    final still1 = walk.position(0, 8.5);
    final still2 = walk.position(0, 10.5);
    expect(still1, still2);
    // 歩いている間は動く(同じ区間の中で)
    expect(walk.position(1, 0.5) == walk.position(1, 4.5), isFalse);
    // こびとごとに出発がずれる
    expect(walk.position(0, 3) == walk.position(1, 3), isFalse);
    expect(walk.isWalking(0, 1), isTrue);
    expect(walk.isWalking(0, 9), isFalse);
  });

  testWidgets('画像があれば、こびとが町の中を歩く(人数ぶん)。タップは町に通る', (tester) async {
    final art = (await tester.runAsync(() => ArtCatalog.load(rootBundle)))!;
    final base = await appWithCoins(tester, 2000);
    final app = AppState(
      pack: base.pack,
      kv: base.kv,
      progress: base.progress,
      economyState: base.current,
      townConfig: base.townConfig,
      art: art,
    );
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(() => app.recordWin(i, moves: 10, stars: 1));
    }
    final ids = app.townConfig.buildings.map((b) => b.id).toList();
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => app.placeBuilding(ids[i], i));
      await tester.runAsync(() => app.upgradeBuilding(ids[i]));
      await tester.runAsync(() => app.upgradeBuilding(ids[i]));
    }
    expect(app.dwellers, 2); // 合計15 → 2人
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(appWidget(app, town: true));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('dwellerLayer')), findsOneWidget);
    expect(find.byKey(const Key('walker-0')), findsOneWidget);
    expect(find.byKey(const Key('walker-1')), findsOneWidget);
    expect(find.byKey(const Key('walker-2')), findsNothing);
    final before = tester.getTopLeft(find.byKey(const Key('walker-0')));
    await tester.pump(const Duration(seconds: 4));
    final after = tester.getTopLeft(find.byKey(const Key('walker-0')));
    expect(before == after, isFalse); // 動いている
    expect(tester.takeException(), isNull);
    // こびとの上のマスもタップできる(IgnorePointer)
    await tester.tap(find.byKey(const Key('cell-0')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('detailSheet')), findsOneWidget);
  });

  testWidgets('画像がなければ歩かせず、従来の表示のまま', (tester) async {
    final app = await appWithCoins(tester, 2000);
    await tester.pumpWidget(appWidget(app, town: true));
    expect(find.byKey(const Key('dwellerLayer')), findsNothing);
  });
}

void seasonTests() {
  testWidgets('置く・育てると、いまの季節の資材を添えたひとことが出る', (tester) async {
    final app = await appWithCoins(tester, 200);
    await tester.pumpWidget(appWidget(app, town: true));
    await tester.tap(find.byKey(const Key('cell-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('place_small_house')));
    await tester.pumpAndSettle();
    // 1〜12面は若草: 木材・わら・つた のうち2つ
    expect(find.textContaining('Placed Small house'), findsOneWidget);
    expect(find.textContaining(RegExp('wood|straw|ivy')), findsWidgets);
    await tester.tap(find.byKey(const Key('cell-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('upgrade')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Grew Small house with'), findsOneWidget);
  });

  test('資材は建物と段階で決まり、季節の資材から2つ', () async {
    final base = await loadApp();
    for (final id in ['small_house', 'bench']) {
      for (final st in [1, 2, 3]) {
        final m = base.materialsFor(id, st);
        expect(m, hasLength(2));
        expect(m.toSet(), hasLength(2));
        expect(base.currentSeason!.materials, containsAll(m));
        expect(base.materialsFor(id, st), m); // 同じ入力なら同じ
      }
    }
  });

  testWidgets('季節を終えると飾りが届き(知らせは1回)、飾りの帯に並ぶ', (tester) async {
    final app = await appWithCoins(tester, 0);
    await tester.pumpWidget(appWidget(app, town: true));
    expect(find.byKey(const Key('newSeasonObject')), findsNothing);
    expect(find.byKey(const Key('seasonStrip')), findsNothing);
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(() => app.recordWin(i, moves: 10, stars: 1));
    }
    await tester.pumpAndSettle();
    // 新しい建物の知らせが先、その後に季節の飾りの知らせ(1度に1枚だけ)
    expect(find.byKey(const Key('newBuilding')), findsOneWidget);
    expect(find.byKey(const Key('newSeasonObject')), findsNothing);
    await tester.tap(find.descendant(
        of: find.byKey(const Key('newBuilding')),
        matching: find.byType(TextButton)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('newSeasonObject')), findsOneWidget);
    expect(find.byKey(const Key('seasonStrip')), findsOneWidget);
    expect(find.byKey(const Key('season-spring')), findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byKey(const Key('newSeasonObject')),
        matching: find.byType(TextButton)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('newSeasonObject')), findsNothing);
    expect(app.seasonsDone, 1);
    expect(app.newSeasonObjects, isEmpty);
  });
}
