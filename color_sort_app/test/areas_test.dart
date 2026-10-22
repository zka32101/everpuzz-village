import 'package:color_sort_app/game/app_state.dart';
import 'package:color_sort_app/l10n/strings.dart';
import 'package:color_sort_app/ui/town_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/foundation.dart';
import 'package:color_sort/color_sort.dart';

import 'helpers.dart';

Future<AppState> richApp(MemoryKeyValueStore kv, Clock clock) async {
  await VersionedJsonStore(kv).save(
    AppState.economyKey,
    AppState.economySchema,
    EconomyState.initial(economyConfig, clock.now())
        .copyWith(coins: 500)
        .toJson(),
  );
  return loadApp(kv: kv, clock: clock);
}

Future<void> openSecondArea(AppState app) async {
  final n = app.packs[0].pack.levels.length;
  for (var i = 0; i < n; i++) {
    await app.recordWin(i, moves: 10, stars: 1);
  }
  expect(await app.selectPack(1), isTrue);
}

void main() {
  test('町はエリアごとに別。最初のエリアは従来の保存キーのまま', () async {
    final kv = MemoryKeyValueStore();
    final clock = FakeClock(DateTime.utc(2026, 1, 1, 12));
    final app = await richApp(kv, clock);
    expect(await app.placeBuilding('small_house', 0), isNull);
    expect(app.townState.placements, hasLength(1));
    expect(await kv.read(TownStore.key), isNotNull); // 従来のキー

    await openSecondArea(app);
    expect(app.townState.placements, isEmpty); // 次のエリアは空の町
    expect(await app.placeBuilding('small_house', 5), isNull);
    expect(await kv.read('town.extra1'), isNotNull);

    // 戻ると元の町、再起動しても保たれる
    await app.selectPack(0);
    expect(app.townState.placementOf('small_house')!.cell, 0);
    final again = await loadApp(kv: kv, clock: clock);
    expect(again.townState.placementOf('small_house')!.cell, 0);
    await again.selectPack(1);
    expect(again.townState.placementOf('small_house')!.cell, 5);
  });

  test('進行を初期に戻すと、どのエリアの町も空になる', () async {
    final kv = MemoryKeyValueStore();
    final clock = FakeClock(DateTime.utc(2026, 1, 1, 12));
    final app = await richApp(kv, clock);
    await app.placeBuilding('small_house', 0);
    await openSecondArea(app);
    await app.placeBuilding('small_house', 1);
    await app.resetProgress();
    expect(app.townState.placements, isEmpty);
    await app.selectPack(0);
    expect(app.townState.placements, isEmpty);
    final again = await loadApp(kv: kv, clock: clock);
    expect(again.townState.placements, isEmpty);
  });

  testWidgets('町の画面にエリア切替が出る。遊べないエリアは鍵つき', (tester) async {
    final app = (await tester.runAsync(loadApp))!;
    await tester.pumpWidget(L10n(
      translator: translatorFor('en'),
      child: MaterialApp(home: TownScreen(app: app)),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('area-main')), findsOneWidget);
    await tester.tap(find.byKey(const Key('area-extra1')));
    await tester.pumpAndSettle();
    expect(app.activePackIndex, 0); // まだ開いていない
  });
}
