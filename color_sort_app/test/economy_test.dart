import 'dart:math';

import 'package:color_sort/color_sort.dart';
import 'package:color_sort_app/game/app_state.dart';
import 'package:color_sort_app/game/game_controller.dart';
import 'package:color_sort_app/l10n/strings.dart';
import 'package:color_sort_app/ui/play_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/foundation.dart';
import 'package:puzzle_core/puzzle.dart';

import 'helpers.dart';

class FakeAds implements AdGate {
  FakeAds(this.result);

  bool result;
  final List<RewardedPlacement> shown = [];

  @override
  Future<bool> showRewarded(RewardedPlacement placement) async {
    shown.add(placement);
    return result;
  }
}

/// 指定の面で、行き詰まる(勝てず合法手もない)手順をランダム探索で見つける。
List<Move> findStuckMoves(AppState app, int index) {
  const rules = ColorSortRules();
  final spec = app.pack.levels[index].spec;
  for (var seed = 0; seed < 2000; seed++) {
    final rnd = Random(seed);
    var s = rules.initial(spec);
    final path = <Move>[];
    for (var step = 0; step < 300 && !rules.isWon(s); step++) {
      final moves = rules.legalMoves(s);
      if (moves.isEmpty) return path;
      final m = moves[rnd.nextInt(moves.length)];
      path.add(m);
      s = rules.apply(s, m);
    }
  }
  throw StateError('行き詰まる手順が見つからない');
}

/// 1面目を最短手順でクリアする(コントローラ経由)。
void solveFirst(AppState app, GameController g) {
  final level = app.pack.levels[0];
  for (final (from, to)
      in solve(const ColorSortRules(), level.spec).solution!) {
    g.tap(from);
    g.tap(to);
  }
}

void main() {
  group('AppState(ライフ・コイン)', () {
    test('初期状態: ライフ満タン・コイン0', () async {
      final app = await loadApp();
      expect(app.lives, economyConfig.maxLives);
      expect(app.coins, 0);
      expect(app.timeToNextLife, isNull);
      expect(app.canPlay, isTrue);
    });

    test('ライフ消費→時間で回復(時計は注入)', () async {
      final clock = FakeClock(DateTime.utc(2026, 1, 1, 12));
      final app = await loadApp(clock: clock);
      expect(await app.loseLife(), isTrue);
      expect(app.lives, economyConfig.maxLives - 1);
      expect(app.timeToNextLife, const Duration(minutes: 30));
      clock.advance(const Duration(minutes: 31));
      expect(app.lives, economyConfig.maxLives);
    });

    test('ライフ切れでは消費できず、遊べない', () async {
      final app = await loadApp();
      for (var i = 0; i < economyConfig.maxLives; i++) {
        expect(await app.loseLife(), isTrue);
      }
      expect(app.lives, 0);
      expect(app.canPlay, isFalse);
      expect(await app.loseLife(), isFalse);
    });

    test('初回クリアだけ固定報酬(2回目は0)', () async {
      final app = await loadApp();
      expect(
          await app.recordWin(0, moves: 7, stars: 3), economyConfig.winReward);
      expect(app.coins, economyConfig.winReward);
      expect(await app.recordWin(0, moves: 7, stars: 3), 0);
      expect(app.coins, economyConfig.winReward);
    });

    test('空き容器の購入: コイン不足は失敗で状態不変、足りれば消費', () async {
      final app = await loadApp();
      expect(await app.buyExtraTube(), isFalse);
      expect(app.coins, 0);
      await app.recordWin(0, moves: 7, stars: 3); // +10
      await app.recordWin(1, moves: 7, stars: 3);
      await app.recordWin(2, moves: 7, stars: 3);
      await app.recordWin(3, moves: 7, stars: 3);
      expect(app.coins, 40);
      expect(await app.buyExtraTube(), isTrue);
      expect(app.coins, 0);
    });

    test('広告: 窓口なしは何もしない/見終われば+1/見なければ回復しない', () async {
      final none = await loadApp();
      await none.loseLife();
      expect(await none.restoreLifeWithAd(), isFalse);

      final ads = FakeAds(true);
      final app = await loadApp(adGate: ads);
      await app.loseLife();
      expect(await app.restoreLifeWithAd(), isTrue);
      expect(app.lives, economyConfig.maxLives);
      expect(ads.shown, [RewardedPlacement.restoreLife]);

      ads.result = false;
      await app.loseLife();
      expect(await app.restoreLifeWithAd(), isFalse);
      expect(app.lives, economyConfig.maxLives - 1);
    });

    test('保存して読み直しても、ライフ・コイン・進行が残る', () async {
      final kv = MemoryKeyValueStore();
      final clock = FakeClock(DateTime.utc(2026, 1, 1, 12));
      final app = await loadApp(kv: kv, clock: clock);
      await app.loseLife();
      await app.recordWin(0, moves: 7, stars: 2);
      final again = await loadApp(kv: kv, clock: clock);
      expect(again.lives, economyConfig.maxLives - 1);
      expect(again.coins, economyConfig.winReward);
      expect(again.progress.recordOf(again.pack.levels[0].id).stars, 2);
    });
  });

  group('空き容器ブースター(コントローラ)', () {
    test('空の容器が1本増え、2回目は使えず、足す前には戻せない', () async {
      final app = await loadApp();
      final g = GameController(app.pack.levels[0]);
      final before = g.board.tubes.length;
      g.tap(0);
      g.tap(g.board.tubes.indexWhere((t) => t.isEmpty));
      expect(g.canUndo, isTrue);
      g.addTube();
      expect(g.board.tubes.length, before + 1);
      expect(g.board.tubes.last, isEmpty);
      expect(g.canUndo, isFalse);
      g.addTube();
      expect(g.board.tubes.length, before + 1);
    });

    test('やり直しても買った容器は持ち越す。星は最大2', () async {
      final app = await loadApp();
      final g = GameController(app.pack.levels[0]);
      g.addTube();
      g.restart();
      expect(
          g.board.tubes.length,
          app.pack.levels[0].spec['tubes']!.toString().isEmpty
              ? 0
              : (app.pack.levels[0].spec['tubes']! as List).length + 1);
      solveFirst(app, g);
      expect(g.won, isTrue);
      expect(g.stars, lessThanOrEqualTo(2));
    });
  });

  group('画面', () {
    testWidgets('ライフとコインが数字で表示される', (tester) async {
      final app = await tester.runAsync(loadApp) as AppState;
      await tester.pumpWidget(appWidget(app));
      expect(find.text('Lives 5/5'), findsOneWidget);
      expect(find.text('Coins 0'), findsOneWidget);
      expect(find.byKey(const Key('nextLife')), findsNothing);
    });

    testWidgets('ライフ切れで面を開くと案内。広告窓口がなければ回復ボタンなし', (tester) async {
      final app = await tester.runAsync(loadApp) as AppState;
      await tester.runAsync(() async {
        for (var i = 0; i < 5; i++) {
          await app.loseLife();
        }
      });
      await tester.pumpWidget(appWidget(app));
      expect(find.text('Lives 0/5'), findsOneWidget);
      expect(find.byKey(const Key('nextLife')), findsOneWidget);
      await tester.tap(find.byKey(const Key('level-0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('noLives')), findsOneWidget);
      expect(find.byKey(const Key('watchAd')), findsNothing);
      expect(find.byKey(const Key('tube-0')), findsNothing);
    });

    testWidgets('広告窓口があれば回復でき、そのまま遊べる', (tester) async {
      final ads = FakeAds(true);
      final app = await tester.runAsync(() => loadApp(adGate: ads)) as AppState;
      await tester.runAsync(() async {
        for (var i = 0; i < 5; i++) {
          await app.loseLife();
        }
      });
      await tester.pumpWidget(appWidget(app));
      await tester.tap(find.byKey(const Key('level-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('watchAd')));
      await tester.pumpAndSettle();
      expect(app.lives, 1);
      expect(find.byKey(const Key('noLives')), findsNothing);
      await tester.tap(find.byKey(const Key('level-0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tube-0')), findsOneWidget);
    });

    testWidgets('クリアで初回報酬が出てコインが増える', (tester) async {
      final app = await tester.runAsync(loadApp) as AppState;
      await tester.pumpWidget(appWidget(app));
      await tester.tap(find.byKey(const Key('level-0')));
      await tester.pumpAndSettle();
      final level = app.pack.levels[0];
      for (final (from, to)
          in solve(const ColorSortRules(), level.spec).solution!) {
        await tester.tap(find.byKey(Key('tube-$from')));
        await tester.pump();
        await tester.tap(find.byKey(Key('tube-$to')));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('win')), findsOneWidget);
      expect(find.text('+10 coins'), findsOneWidget);
      expect(find.text('Coins 10'), findsOneWidget);
    });

    testWidgets('コイン不足で空き容器を買おうとすると案内が出て、容器は増えない', (tester) async {
      final app = await tester.runAsync(loadApp) as AppState;
      await tester.pumpWidget(appWidget(app));
      await tester.tap(find.byKey(const Key('level-0')));
      await tester.pumpAndSettle();
      final before = (app.pack.levels[0].spec['tubes']! as List).length;
      await tester.tap(find.byKey(const Key('extraTube')));
      await tester.pumpAndSettle();
      expect(find.text('Not enough coins.'), findsOneWidget);
      expect(find.byKey(Key('tube-$before')), findsNothing);
    });

    testWidgets('コインがあれば買って容器が増え、コインが減る', (tester) async {
      final app = await tester.runAsync(loadApp) as AppState;
      await tester.runAsync(() async {
        for (var i = 0; i < 4; i++) {
          await app.recordWin(i, moves: 7, stars: 3);
        }
      });
      await tester.pumpWidget(appWidget(app));
      await tester.tap(find.byKey(const Key('level-0')));
      await tester.pumpAndSettle();
      final before = (app.pack.levels[0].spec['tubes']! as List).length;
      await tester.tap(find.byKey(const Key('extraTube')));
      await tester.pumpAndSettle();
      expect(find.byKey(Key('tube-$before')), findsOneWidget);
      expect(app.coins, 0);
      // 2回目は押せない
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('extraTube')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('行き詰まるとライフを1つ失い、戻しても二重に取られず、やり直して再び詰むとまた失う', (tester) async {
      // 空容器が少ない面(36面目)は行き詰まりやすい。
      const index = 35;
      final app = await tester.runAsync(loadApp) as AppState;
      final stuck = findStuckMoves(app, index);
      await tester.binding.setSurfaceSize(const Size(900, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(L10n(
        translator: translatorFor('en'),
        child: MaterialApp(home: PlayScreen(app: app, index: index)),
      ));

      Future<void> play() async {
        for (final (from, to) in stuck) {
          await tester.tap(find.byKey(Key('tube-$from')));
          await tester.pump();
          await tester.tap(find.byKey(Key('tube-$to')));
          await tester.pump();
        }
        await tester.pumpAndSettle();
      }

      await play();
      expect(app.lives, 4);
      expect(find.text('No moves left. You lost a life. Undo or restart.'),
          findsOneWidget);
      expect(find.text('Lives 4/5'), findsOneWidget);

      // 戻して、同じ手でまた詰んでも、同じプレイ中は二重に失わない。
      await tester.tap(find.byKey(const Key('undo')));
      await tester.pumpAndSettle();
      final (from, to) = stuck.last;
      await tester.tap(find.byKey(Key('tube-$from')));
      await tester.pump();
      await tester.tap(find.byKey(Key('tube-$to')));
      await tester.pumpAndSettle();
      expect(app.lives, 4);

      // やり直して再び詰むと、また1つ失う。
      await tester.tap(find.byKey(const Key('restart')));
      await tester.pumpAndSettle();
      await play();
      expect(app.lives, 3);
    });
  });
}
