import 'package:color_sort_app/game/app_state.dart';
import 'package:color_sort_app/l10n/strings.dart';
import 'package:color_sort_app/ui/journey_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/foundation.dart';

import 'helpers.dart';

Future<AppState> played() async {
  final kv = MemoryKeyValueStore();
  final clock = FakeClock(DateTime.utc(2026, 1, 1, 12));
  await VersionedJsonStore(kv).save(
    AppState.economyKey,
    AppState.economySchema,
    EconomyState.initial(economyConfig, clock.now())
        .copyWith(coins: 500)
        .toJson(),
  );
  final app = await loadApp(kv: kv, clock: clock);
  await app.recordWin(0, moves: 10, stars: 3);
  await app.recordWin(1, moves: 10, stars: 1);
  await app.placeBuilding('small_house', 0);
  await app.upgradeBuilding('small_house');
  return app;
}

void main() {
  test('あゆみの数字: 面・星・建物・段階・エリア', () async {
    final app = await played();
    final j = app.journey;
    expect(j.levelsCleared, 2);
    expect(j.levelsTotal, 180);
    expect(j.stars, 4);
    expect(j.starsMax, 540);
    expect(j.buildingsPlaced, 1);
    expect(j.buildingStages, 2);
    expect(j.areas.map((a) => a.id), ['main', 'extra1', 'extra2']);
    expect(j.areas.map((a) => a.available), [true, false, false]);
    expect(j.areas[0].levelsCleared, 2);
    expect(j.areas[0].buildings, 1);
  });

  test('はじめは、すべて0(遊べるのは最初のエリアだけ)', () async {
    final j = (await loadApp()).journey;
    expect(j.levelsCleared, 0);
    expect(j.stars, 0);
    expect(j.buildingsPlaced, 0);
    expect(j.dwellers, 0);
  });

  testWidgets('あゆみの画面に数字が出る。先のエリアは「まだ先です」', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final app = (await tester.runAsync(played))!;
    await tester.pumpWidget(L10n(
      translator: translatorFor('en'),
      child: MaterialApp(home: JourneyScreen(app: app)),
    ));
    await tester.pump();
    expect(find.text('2 / 180'), findsOneWidget);
    expect(find.text('4 / 540'), findsOneWidget);
    expect(find.byKey(const Key('journey-buildings')), findsOneWidget);
    expect(find.text('Not yet'), findsNWidgets(2));
  });
}
