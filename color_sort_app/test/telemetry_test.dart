import 'package:color_sort/color_sort.dart';
import 'package:color_sort_app/game/app_state.dart';
import 'package:color_sort_app/l10n/strings.dart';
import 'package:color_sort_app/ui/play_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/foundation.dart';
import 'package:puzzle_core/puzzle.dart';

import 'economy_test.dart' show FakeAds, findStuckMoves;
import 'helpers.dart';

Widget play(AppState app, int index) => L10n(
      translator: translatorFor('en'),
      child: MaterialApp(home: PlayScreen(app: app, index: index)),
    );

Future<void> tapMoves(WidgetTester tester, Iterable<Move> moves) async {
  for (final (from, to) in moves) {
    await tester.tap(find.byKey(Key('tube-$from')));
    await tester.pump();
    await tester.tap(find.byKey(Key('tube-$to')));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

List<String> names(MemoryTelemetry t) => [for (final e in t.events) e.name];

void main() {
  testWidgets('開始→クリアで level_start / level_win(手数つき)が出る', (tester) async {
    final tel = MemoryTelemetry();
    final app =
        await tester.runAsync(() => loadApp(telemetry: tel)) as AppState;
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(play(app, 0));
    expect(names(tel), ['level_start']);
    expect(tel.events.single.params, {'levelId': 'main-001', 'attempt': 1});

    final solution =
        solve(const ColorSortRules(), app.pack.levels[0].spec).solution!;
    await tapMoves(tester, solution);
    expect(names(tel), ['level_start', 'level_win']);
    expect(tel.events.last.params,
        {'levelId': 'main-001', 'attempt': 1, 'moves': solution.length});
  });

  testWidgets('行き詰まりで level_fail、やり直しで attempt が増えて level_start、失敗は試行回数に残る',
      (tester) async {
    final tel = MemoryTelemetry();
    final app =
        await tester.runAsync(() => loadApp(telemetry: tel)) as AppState;
    const index = 35;
    final stuck = findStuckMoves(app, index);
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(play(app, index));
    await tapMoves(tester, stuck);
    expect(names(tel), ['level_start', 'level_fail']);
    expect(tel.events.last.params['moves'], stuck.length);
    expect(app.progress.recordOf(app.pack.levels[index].id).attempts, 1);
    expect(app.progress.recordOf(app.pack.levels[index].id).cleared, isFalse);

    await tester.tap(find.byKey(const Key('restart')));
    await tester.pumpAndSettle();
    expect(names(tel), ['level_start', 'level_fail', 'level_start']);
    expect(tel.events.last.params['attempt'], 2);
  });

  testWidgets('空き容器の購入で booster_used、広告で回復すると ad_shown', (tester) async {
    final tel = MemoryTelemetry();
    final ads = FakeAds(true);
    final app = await tester
        .runAsync(() => loadApp(telemetry: tel, adGate: ads)) as AppState;
    await tester.runAsync(() async {
      for (var i = 0; i < 4; i++) {
        await app.recordWin(i, moves: 7, stars: 3); // コイン40
      }
      await app.loseLife();
    });
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(play(app, 0));
    await tester.tap(find.byKey(const Key('extraTube')));
    await tester.pumpAndSettle();
    expect(names(tel), ['level_start', 'booster_used']);
    expect(tel.events.last.params,
        {'levelId': 'main-001', 'boosterId': 'extraTube'});

    await tester.runAsync(app.restoreLifeWithAd);
    expect(names(tel).last, 'ad_shown');
    expect(tel.events.last.params, {'placement': 'restoreLife'});
  });

  test('窓口が未接続(Noop)でもアプリは動く', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final app = await loadApp();
    expect(app.telemetry, isA<NoopTelemetry>());
  });
}
