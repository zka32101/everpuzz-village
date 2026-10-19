import 'package:color_sort/color_sort.dart';
import 'package:color_sort_app/game/app_state.dart';
import 'package:color_sort_app/game/game_controller.dart';
import 'package:color_sort_app/game/hint.dart';
import 'package:color_sort_app/l10n/strings.dart';
import 'package:color_sort_app/ui/play_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/foundation.dart';
import 'package:puzzle_core/puzzle.dart';

import 'helpers.dart';

Widget play(AppState app, int index) => L10n(
      translator: translatorFor('en'),
      child: MaterialApp(home: PlayScreen(app: app, index: index)),
    );

Future<AppState> richApp(WidgetTester tester, {HintSolver? hintSolver}) async {
  final app =
      await tester.runAsync(() => loadApp(hintSolver: hintSolver)) as AppState;
  await tester.runAsync(() async {
    for (var i = 0; i < 4; i++) {
      await app.recordWin(i, moves: 7, stars: 3); // コイン40
    }
  });
  return app;
}

void main() {
  const rules = ColorSortRules();

  group('ヒントの計算', () {
    test('盤面を spec に戻して往復できる(鍵つきも)', () async {
      final app = await loadApp();
      for (final i in [0, 32, 51]) {
        final spec = app.pack.levels[i].spec;
        final board = rules.initial(spec);
        final back = rules.initial(boardToSpec(board));
        expect(back.tubes, board.tubes, reason: 'level $i');
        expect([
          for (final l in back.locks) l?.toString()
        ], [
          for (final l in board.locks) l?.toString()
        ], reason: 'level $i');
      }
    });

    test('ヒントは合法で、1手進めると最短手数がちょうど1減る', () async {
      final app = await loadApp();
      for (final i in [0, 5, 12, 32]) {
        final spec = app.pack.levels[i].spec;
        final board = rules.initial(spec);
        final min = solve(rules, spec).minMoves!;
        final move = solveHint(board)!;
        expect(rules.legalMoves(board), contains(move), reason: 'level $i');
        final next = rules.apply(board, move);
        final rest = solve(rules, boardToSpec(next)).minMoves;
        expect(rest, min - 1, reason: 'level $i');
      }
    });

    test('すでに詰んでいる盤面ではヒントなし', () {
      final board = rules.initial({
        'capacity': 4,
        'tubes': [
          [0, 1, 0, 1],
          [1, 0, 1, 0],
        ],
      });
      expect(solveHint(board), isNull);
    });

    test('別 isolate 版も同じ手を返す', () async {
      final app = await loadApp();
      final board = rules.initial(app.pack.levels[3].spec);
      expect(await isolateHintSolver(board), solveHint(board));
    });
  });

  group('コントローラ', () {
    test('ヒントは次の操作(タップ・戻す・やり直し)で消える', () async {
      final app = await loadApp();
      final g = GameController(app.pack.levels[0]);
      final m = solveHint(g.board)!;
      g.showHint(m);
      expect(g.hint, m);
      g.tap(0);
      expect(g.hint, isNull);
      g.showHint(m);
      g.restart();
      expect(g.hint, isNull);
    });
  });

  group('画面', () {
    testWidgets('ヒントを使うと、コインが減り、ここから/ここへが文字で出る', (tester) async {
      final app = await richApp(tester);
      await tester.binding.setSurfaceSize(const Size(900, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(play(app, 0));
      final expected = solveHint(rules.initial(app.pack.levels[0].spec))!;
      expect(app.coins, 40);
      await tester.tap(find.byKey(const Key('hint')));
      await tester.pumpAndSettle();
      expect(app.coins, 40 - app.hintCost);
      expect(find.byKey(const Key('hint-from')), findsOneWidget);
      expect(find.byKey(const Key('hint-to')), findsOneWidget);
      expect(find.text('From here'), findsOneWidget);
      expect(find.text('To here'), findsOneWidget);
      expect(
        find.text('Tube ${expected.$1 + 1} to tube ${expected.$2 + 1}'),
        findsOneWidget,
      );
      // 示された手のとおりにタップすると、ヒント表示は消える
      await tester.tap(find.byKey(Key('tube-${expected.$1}')));
      await tester.pump();
      expect(find.byKey(const Key('hint-from')), findsNothing);
    });

    testWidgets('コイン不足なら案内だけで、ヒントは出ない', (tester) async {
      final app = await tester.runAsync(loadApp) as AppState;
      await tester.pumpWidget(play(app, 0));
      await tester.tap(find.byKey(const Key('hint')));
      await tester.pumpAndSettle();
      expect(find.text('Not enough coins.'), findsOneWidget);
      expect(find.byKey(const Key('hint-from')), findsNothing);
    });

    testWidgets('手が見つからなければ課金されない', (tester) async {
      final app = await richApp(tester, hintSolver: (_) async => null);
      await tester.pumpWidget(play(app, 0));
      await tester.tap(find.byKey(const Key('hint')));
      await tester.pumpAndSettle();
      expect(app.coins, 40);
      expect(find.text('No move found. Coins were not spent.'), findsOneWidget);
      expect(find.byKey(const Key('hint-from')), findsNothing);
    });

    testWidgets('ヒントの利用が計測される', (tester) async {
      final tel = MemoryTelemetry();
      final app =
          await tester.runAsync(() => loadApp(telemetry: tel)) as AppState;
      await tester.runAsync(() async {
        for (var i = 0; i < 4; i++) {
          await app.recordWin(i, moves: 7, stars: 3);
        }
      });
      await tester.binding.setSurfaceSize(const Size(900, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(play(app, 0));
      await tester.tap(find.byKey(const Key('hint')));
      await tester.pumpAndSettle();
      expect(tel.events.last.name, 'booster_used');
      expect(tel.events.last.params['boosterId'], 'hint');
    });

    testWidgets('ヒントの案内に従って最後まで解ける(毎手ヒント)', (tester) async {
      final app = await tester.runAsync(loadApp) as AppState;
      await tester.runAsync(() async {
        // 十分なコイン(毎回ヒントを買う)
        for (var i = 0; i < 40; i++) {
          await app.recordWin(i, moves: 7, stars: 3);
        }
      });
      await tester.binding.setSurfaceSize(const Size(900, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(play(app, 0));
      final min = app.pack.levels[0].verified!.minMoves!;
      for (var step = 0; step < min; step++) {
        await tester.tap(find.byKey(const Key('hint')));
        await tester.pumpAndSettle();
        final from = find.byKey(const Key('hint-from'));
        expect(from, findsOneWidget, reason: 'step $step');
        final board = rules.initial(app.pack.levels[0].spec);
        // 画面のヒントのとおりにタップ(from の容器、to の容器)
        final fromKey = _tubeIndexNear(tester, 'hint-from');
        final toKey = _tubeIndexNear(tester, 'hint-to');
        expect(board.tubes.length, greaterThan(fromKey));
        await tester.tap(find.byKey(Key('tube-$fromKey')));
        await tester.pump();
        await tester.tap(find.byKey(Key('tube-$toKey')));
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const Key('win')), findsOneWidget);
      expect(find.text('Cleared!'), findsOneWidget);
    });
  });
}

/// ヒント表示(hint-from / hint-to)を含む容器の番号を返す。
int _tubeIndexNear(WidgetTester tester, String hintKey) {
  final finder = find.ancestor(
    of: find.byKey(Key(hintKey)),
    matching: find.byWidgetPredicate((w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('tube-')),
  );
  final key = (tester.widget(finder.first).key! as ValueKey<String>).value;
  return int.parse(key.substring('tube-'.length));
}
