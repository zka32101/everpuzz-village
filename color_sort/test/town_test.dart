import 'dart:io';

import 'package:color_sort/color_sort.dart';
import 'package:puzzle_core/foundation.dart';
import 'package:test/test.dart';

void main() {
  final config = TownConfig.fromJson(
      File('assets/town/buildings.json').readAsStringSync());
  const empty = TownState.empty;
  final rules = TownRules(config);

  test('同梱の設定は検査を通る', () {
    expect(config.validate(levelCount: 60), isEmpty);
    expect(config.buildings, hasLength(20));
    expect(config.totalCost, 1500);
  });

  test('検査: 重複・費用・範囲外・マス不足を検出', () {
    TownConfig with_(List<BuildingDef> b, {int maxCells = 24}) => TownConfig(
        columns: 4,
        maxCells: maxCells,
        spareCells: 4,
        dailyGift: 10,
        pointsPerDweller: 6,
        maxDwellers: 10,
        buildings: b);
    BuildingDef d(String id, int at, List<int> c) =>
        BuildingDef(id: id, category: 'x', unlockAfterLevels: at, costs: c);
    expect(
        with_([
          d('a', 0, [1, 2, 3]),
          d('a', 3, [1, 2, 3])
        ]).validate(levelCount: 60),
        contains('建物IDが重複: a'));
    expect(
        with_([
          d('a', 0, [5, 5, 6])
        ]).validate(levelCount: 60),
        contains('a: 費用は段階ごとに増やす'));
    expect(
        with_([
          d('a', 0, [0, 1, 2])
        ]).validate(levelCount: 60),
        contains('a: 費用は正の数'));
    expect(
        with_([
          d('a', 0, [1, 2, 3]),
          d('b', 99, [1, 2, 3])
        ]).validate(levelCount: 60),
        contains('b: 解放面が範囲外(99)'));
    expect(
        with_([
          d('a', 0, [1, 2, 3]),
          d('b', 3, [1, 2, 3])
        ], maxCells: 1)
            .validate(levelCount: 60)
            .any((e) => e.contains('マス数')),
        isTrue);
  });

  test('解放は3面ごとに1種。最初の1種は最初から、20種目は57面', () {
    expect(rules.unlocked(0).map((b) => b.id), ['small_house']);
    expect(rules.unlocked(2), hasLength(1));
    expect(rules.unlocked(3), hasLength(2));
    expect(rules.unlocked(56), hasLength(19));
    expect(rules.unlocked(57), hasLength(20));
    expect(rules.unlocked(60), hasLength(20));
  });

  test('マス数は解放数+4、最大24', () {
    expect(rules.cellCount(0), 5);
    expect(rules.cellCount(3), 6);
    expect(rules.cellCount(57), 24);
  });

  test('置く: 費用・重複・未解放・範囲外・埋まっているマス・コイン不足', () {
    final ok =
        rules.place(empty, 'small_house', 0, clearedLevels: 0, coins: 15);
    expect(ok.ok, isTrue);
    expect(ok.cost, 15);
    expect(ok.state!.placementOf('small_house')!.stage, 1);

    TownError? err(TownState s, String id, int cell,
            {int cleared = 0, int coins = 999}) =>
        rules.place(s, id, cell, clearedLevels: cleared, coins: coins).error;
    expect(err(ok.state!, 'small_house', 1), TownError.alreadyPlaced);
    expect(err(empty, 'mushroom_house', 0), TownError.locked);
    expect(err(empty, 'nothing', 0), TownError.locked);
    expect(err(empty, 'small_house', 5), TownError.cellOutOfRange);
    expect(err(empty, 'small_house', -1), TownError.cellOutOfRange);
    expect(
        err(ok.state!, 'mushroom_house', 0, cleared: 3), TownError.cellTaken);
    expect(err(empty, 'small_house', 0, coins: 14), TownError.notEnoughCoins);
  });

  test('育てる: 25→35、最大で止まる、コイン不足は変化なし', () {
    var s = rules
        .place(empty, 'small_house', 0, clearedLevels: 0, coins: 99)
        .state!;
    expect(rules.upgrade(s, 'small_house', coins: 24).error,
        TownError.notEnoughCoins);
    final r2 = rules.upgrade(s, 'small_house', coins: 25);
    expect(r2.cost, 25);
    s = r2.state!;
    final r3 = rules.upgrade(s, 'small_house', coins: 35);
    expect(r3.cost, 35);
    s = r3.state!;
    expect(s.placementOf('small_house')!.stage, 3);
    expect(
        rules.upgrade(s, 'small_house', coins: 999).error, TownError.maxStage);
    expect(rules.upgrade(empty, 'small_house', coins: 999).error,
        TownError.notPlaced);
  });

  test('動かす: 空きマスへ移動、建物があれば入れ替え、費用なし', () {
    var s = rules
        .place(empty, 'small_house', 0, clearedLevels: 3, coins: 99)
        .state!;
    s = rules.place(s, 'mushroom_house', 1, clearedLevels: 3, coins: 99).state!;
    final moved = rules.move(s, 'small_house', 4, clearedLevels: 3);
    expect(moved.cost, 0);
    expect(moved.state!.placementOf('small_house')!.cell, 4);
    final swapped = rules.move(s, 'small_house', 1, clearedLevels: 3);
    expect(swapped.state!.placementOf('small_house')!.cell, 1);
    expect(swapped.state!.placementOf('mushroom_house')!.cell, 0);
    expect(rules.move(s, 'small_house', 0, clearedLevels: 3).error,
        TownError.sameCell);
    expect(rules.move(s, 'small_house', 9, clearedLevels: 3).error,
        TownError.cellOutOfRange);
    expect(
        rules.move(s, 'bench', 2, clearedLevels: 3).error, TownError.notPlaced);
  });

  test('置ける一覧は、解放済みで未設置のもの', () {
    final s = rules
        .place(empty, 'small_house', 0, clearedLevels: 3, coins: 99)
        .state!;
    expect(rules.placeable(s, 3).map((b) => b.id), ['mushroom_house']);
  });

  test('完成・満開・合計段階・こびと', () {
    var s = empty;
    for (var i = 0; i < 20; i++) {
      s = rules
          .place(s, config.buildings[i].id, i, clearedLevels: 60, coins: 999)
          .state!;
    }
    expect(rules.isComplete(s), isTrue);
    expect(rules.isBloom(s), isFalse);
    expect(rules.stagePoints(s), 20);
    expect(rules.dwellers(s), 3);
    for (final b in config.buildings) {
      for (var k = 0; k < 2; k++) {
        s = rules.upgrade(s, b.id, coins: 999).state!;
      }
    }
    expect(rules.stagePoints(s), 60);
    expect(rules.dwellers(s), 10);
    expect(rules.isBloom(s), isTrue);
    expect(rules.dwellers(empty), 0);
  });

  test('町全体の費用は、置く+育てるの合計と一致する', () {
    var s = empty;
    var spent = 0;
    for (var i = 0; i < 20; i++) {
      final r = rules.place(s, config.buildings[i].id, i,
          clearedLevels: 60, coins: 999);
      spent += r.cost;
      s = r.state!;
    }
    for (final b in config.buildings) {
      for (var k = 0; k < 2; k++) {
        final r = rules.upgrade(s, b.id, coins: 999);
        spent += r.cost;
        s = r.state!;
      }
    }
    expect(spent, config.totalCost);
  });

  test('日替わりの贈り物は1日1回(日付が変われば再び。連続は問わない)', () {
    final d1 = DateTime(2026, 10, 20, 8);
    expect(rules.canClaimGift(empty, d1), isTrue);
    final s = rules.claimGift(empty, d1)!.state!;
    expect(s.lastGiftDay, '2026-10-20');
    expect(rules.canClaimGift(s, DateTime(2026, 10, 20, 23)), isFalse);
    expect(rules.claimGift(s, d1), isNull);
    expect(rules.canClaimGift(s, DateTime(2026, 10, 25)), isTrue);
  });

  test('新しい建物の知らせは1回だけ(解放数に追いつくまで)', () {
    var s = empty;
    expect(rules.newlyUnlocked(s, 0), isEmpty);
    expect(rules.newlyUnlocked(s, 3).map((b) => b.id), ['mushroom_house']);
    expect(rules.newlyUnlocked(s, 7).map((b) => b.id),
        ['mushroom_house', 'windmill_house']);
    s = rules.markUnlocksSeen(s, 7);
    expect(rules.newlyUnlocked(s, 7), isEmpty);
    expect(rules.newlyUnlocked(s, 9).map((b) => b.id), ['treehouse']);
  });

  test('完成・満開の知らせは1回だけ', () {
    var s = empty;
    for (var i = 0; i < 20; i++) {
      s = rules
          .place(s, config.buildings[i].id, i, clearedLevels: 60, coins: 999)
          .state!;
    }
    expect(rules.shouldShowComplete(s), isTrue);
    expect(rules.shouldShowBloom(s), isFalse);
    s = s.copyWith(completeShown: true);
    expect(rules.shouldShowComplete(s), isFalse);
    for (final b in config.buildings) {
      for (var k = 0; k < 2; k++) {
        s = rules.upgrade(s, b.id, coins: 999).state!;
      }
    }
    expect(rules.shouldShowBloom(s), isTrue);
    expect(rules.shouldShowBloom(s.copyWith(bloomShown: true)), isFalse);
  });

  test('季節: 12面ごとに季節が替わり、終えるごとに飾りが1つ贈られる(知らせは1回)', () {
    expect(config.seasons.map((e) => e.theme),
        ['spring', 'autumn', 'winter', 'summer', 'sakura']);
    expect(config.validate(levelCount: 60), isEmpty);
    expect(rules.seasonAt(0)!.theme, 'spring');
    expect(rules.seasonAt(12)!.theme, 'autumn');
    expect(rules.seasonAt(59)!.theme, 'sakura');
    expect(rules.seasonAt(999)!.theme, 'sakura');
    expect(rules.seasonsDone(11), 0);
    expect(rules.seasonsDone(12), 1);
    expect(rules.seasonsDone(60), 5);
    expect(rules.seasonsDone(999), 5);
    var s = empty;
    expect(rules.newSeasonObjects(s, 11), isEmpty);
    expect(rules.newSeasonObjects(s, 25), [0, 1]);
    s = rules.markSeasonsSeen(s, 25);
    expect(rules.newSeasonObjects(s, 25), isEmpty);
    expect(rules.newSeasonObjects(s, 36), [2]);
  });

  test('資材は季節ごとに3つ。IDの重複なし(名前は l10n、画像は material_<ID>)', () {
    final all = [for (final e in config.seasons) ...e.materials];
    expect(all, hasLength(15));
    expect(all.toSet(), hasLength(15));
  });

  group('保存', () {
    test('往復できる', () async {
      final kv = MemoryKeyValueStore();
      final store = TownStore(kv, config);
      var s = rules
          .place(empty, 'small_house', 2, clearedLevels: 0, coins: 99)
          .state!;
      s = rules.upgrade(s, 'small_house', coins: 99).state!;
      s = rules.claimGift(s, DateTime(2026, 10, 20))!.state!;
      await store.save(s);
      final back = await store.load();
      expect(back.placements.single.cell, 2);
      expect(back.placements.single.stage, 2);
      expect(back.lastGiftDay, '2026-10-20');
      final marked =
          rules.markUnlocksSeen(back, 9).copyWith(completeShown: true);
      await store.save(marked);
      final again = await store.load();
      expect(again.seenUnlocked, 4);
      expect(again.completeShown, isTrue);
      final withSeasons = rules.markSeasonsSeen(again, 25);
      await store.save(withSeasons);
      expect((await store.load()).seenSeasons, 2);
    });

    test('未保存・破損・将来版は空の町', () async {
      final kv = MemoryKeyValueStore();
      final store = TownStore(kv, config);
      expect((await store.load()).placements, isEmpty);
      await kv.write(TownStore.key, 'not json');
      expect((await store.load()).placements, isEmpty);
      await kv.write(TownStore.key, '{"v":99,"data":{}}');
      expect((await store.load()).placements, isEmpty);
      await kv.write(TownStore.key, '{"v":1,"data":{"placements":"x"}}');
      expect((await store.load()).placements, isEmpty);
    });

    test('壊れた項目(未知ID・範囲外・段階外・重複)は捨てる', () async {
      final kv = MemoryKeyValueStore();
      await kv.write(
          TownStore.key,
          '{"v":1,"data":{"placements":['
          '{"id":"small_house","cell":0,"stage":1},'
          '{"id":"ghost","cell":1,"stage":1},'
          '{"id":"bench","cell":99,"stage":1},'
          '{"id":"cafe","cell":2,"stage":7},'
          '{"id":"small_house","cell":3,"stage":2},'
          '{"id":"bakery","cell":0,"stage":1}]}}');
      final s = await TownStore(kv, config).load();
      expect(s.placements.map((p) => p.buildingId), ['small_house']);
    });
  });

  group('経済の整合', () {
    test('いまの数値: 費用÷最小=1.25、費用÷最大=0.83、警告なし', () {
      final b = TownBalance.compute(config,
          levelCount: 60, firstClear: 20, starBonus: 5);
      expect(b.minIncome, 1200);
      expect(b.maxIncome, 1800);
      expect(b.vsMin, closeTo(1.25, 1e-9));
      expect(b.vsMax, closeTo(0.833, 0.001));
      expect(b.warnings(), isEmpty);
    });

    test('極端なずれは警告', () {
      final low = TownBalance.compute(config,
          levelCount: 60, firstClear: 5, starBonus: 1);
      expect(low.warnings(), isNotEmpty);
      final high = TownBalance.compute(config,
          levelCount: 60, firstClear: 100, starBonus: 20);
      expect(high.warnings(), isNotEmpty);
    });
  });
}
