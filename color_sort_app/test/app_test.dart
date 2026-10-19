import 'package:color_sort/color_sort.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/foundation.dart';
import 'package:puzzle_core/puzzle.dart';

import 'helpers.dart';

void main() {
  testWidgets('同梱の60面が読め、1面目だけ遊べる', (tester) async {
    final app = await tester.runAsync(loadApp) as dynamic;
    expect(app.pack.levels, hasLength(60));
    expect(app.pack.validate(), isEmpty);
    await tester.pumpWidget(appWidget(app));
    expect(find.text('Everpuzz'), findsOneWidget);
    expect(app.isUnlocked(0), isTrue);
    expect(app.isUnlocked(1), isFalse);
    // 未解放の面を押しても進まない
    await tester.tap(find.byKey(const Key('level-1')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tube-0')), findsNothing);
  });

  testWidgets('ソルバーの解どおりにタップして1面をクリアし、進行が保存・解放される', (tester) async {
    final kv = MemoryKeyValueStore();
    final app = await tester.runAsync(() => loadApp(kv: kv)) as dynamic;
    await tester.pumpWidget(appWidget(app));
    await tester.tap(find.byKey(const Key('level-0')));
    await tester.pumpAndSettle();

    final level = app.pack.levels[0] as LevelEntry;
    final solution = solve(const ColorSortRules(), level.spec).solution!;
    for (final (from, to) in solution) {
      await tester.tap(find.byKey(Key('tube-$from')));
      await tester.pump();
      await tester.tap(find.byKey(Key('tube-$to')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('win')), findsOneWidget);
    expect(find.text('Cleared!'), findsOneWidget);
    expect(app.progress.recordOf(level.id).stars, 3); // 最短手数でクリア
    expect(app.isUnlocked(1), isTrue);
    // 保存された
    final saved = await tester.runAsync(() => KeyValueProgressStore(kv).load());
    expect(saved!.recordOf(level.id).cleared, isTrue);
  });

  testWidgets('通らない手では理由が表示される', (tester) async {
    final app = await tester.runAsync(loadApp) as dynamic;
    await tester.pumpWidget(appWidget(app));
    await tester.tap(find.byKey(const Key('level-0')));
    await tester.pumpAndSettle();
    // 空の容器を最初に押しても何も起きない。中身のある容器→上の色が合わない容器を探して押す。
    final level = app.pack.levels[0] as LevelEntry;
    final tubes = (level.spec['tubes']! as List).cast<List>();
    int? a, b;
    for (var i = 0; i < tubes.length && b == null; i++) {
      for (var j = 0; j < tubes.length; j++) {
        if (i != j &&
            tubes[i].isNotEmpty &&
            tubes[j].isNotEmpty &&
            tubes[j].length < 4 && // 満杯だと理由が「いっぱい」になる
            tubes[i].last != tubes[j].last) {
          a = i;
          b = j;
          break;
        }
      }
    }
    await tester.tap(find.byKey(Key('tube-$a')));
    await tester.pump();
    await tester.tap(find.byKey(Key('tube-$b')));
    await tester.pump();
    expect(find.byKey(const Key('message')), findsOneWidget);
    expect(find.text('The top color does not match.'), findsOneWidget);
  });

  testWidgets('日本語表示と、文字200%で溢れない(レベル選択・プレイ)', (tester) async {
    final app = await tester.runAsync(loadApp) as dynamic;
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(appWidget(app, lang: 'ja', textScale: 2.0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('level-0')));
    await tester.pumpAndSettle();
    expect(find.text('レベル 1'), findsOneWidget);
    expect(find.text('ひとつ戻す'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('操作部品のタップ領域は44pt以上', (tester) async {
    final app = await tester.runAsync(loadApp) as dynamic;
    await tester.pumpWidget(appWidget(app));
    for (final i in [0, 1]) {
      expect(tester.getSize(find.byKey(Key('level-$i'))).shortestSide,
          greaterThanOrEqualTo(44));
    }
    await tester.tap(find.byKey(const Key('level-0')));
    await tester.pumpAndSettle();
    for (final k in ['tube-0', 'undo', 'restart']) {
      final size = tester.getSize(find.byKey(Key(k)));
      expect(size.width, greaterThanOrEqualTo(44), reason: k);
      expect(size.height, greaterThanOrEqualTo(44), reason: k);
    }
  });
}
