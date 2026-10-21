import 'package:color_sort_app/game/art.dart';
import 'package:color_sort_app/game/app_state.dart';
import 'package:color_sort_app/l10n/strings.dart';
import 'package:color_sort_app/ui/play_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// ヒント表示中も、全部の容器が見える。ヒントの文は盤面の下のひとこと欄に出し、
/// スナックバー(下のボタンを隠す)は使わない。
void main() {
  Future<void> check(WidgetTester tester, Size size,
      {required bool art, bool fullyVisible = true}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final base = (await tester.runAsync(() => loadApp()))!;
    final catalog = art
        ? (await tester.runAsync(() => ArtCatalog.load(rootBundle)))!
        : ArtCatalog.empty;
    final app = AppState(
      pack: base.pack,
      kv: base.kv,
      progress: base.progress,
      economyState: base.current.copyWith(coins: 500),
      townConfig: base.townConfig,
      art: catalog,
      hintSolver: base.hintSolver,
    );
    await tester.pumpWidget(L10n(
      translator: translatorFor('en'),
      child: MaterialApp(home: PlayScreen(app: app, index: 40)),
    ));
    await tester.pumpAndSettle();
    List<Rect> rects() {
      final out = <Rect>[];
      var j = 0;
      while (find.byKey(Key('tube-$j')).evaluate().isNotEmpty) {
        out.add(tester.getRect(find.byKey(Key('tube-$j'))));
        j++;
      }
      return out;
    }

    final before = rects();
    await tester.tap(find.byKey(const Key('hint')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('hint-from')), findsOneWidget);
    expect(find.byKey(const Key('hint-to')), findsOneWidget);
    // ヒントの文は盤面の下のひとこと欄に出る(スナックバーではない)
    expect(find.byKey(const Key('message')), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    // ヒントを出しても、容器の位置は動かない(「ここから」の文字で幅が広がり、
    // その容器が段から押し出されて他の容器が画面の外に出ていた)
    final after = rects();
    expect(after, before);
    if (fullyVisible) {
      // 盤面の領域(下のボタンの上まで)に、全部の容器が収まる(スクロールが要らない)
      final limit = tester.getRect(find.byKey(const Key('undo'))).top;
      for (var i = 0; i < after.length; i++) {
        final r = after[i];
        expect(
            r.top >= 0 &&
                r.bottom <= limit &&
                r.left >= 0 &&
                r.right <= size.width,
            isTrue,
            reason: '容器 $i が盤面の領域に収まらない: $r (ボタンの上端 $limit)');
      }
    }
    expect(after.length, greaterThanOrEqualTo(5));
    // 下のボタンも隠れない
    expect(tester.getRect(find.byKey(const Key('undo'))).bottom,
        lessThanOrEqualTo(size.height));
  }

  testWidgets('ヒント表示中も全部の容器が見える(360x800・画像あり)', (tester) async {
    await check(tester, const Size(360, 800), art: true);
  });

  testWidgets('小さい画面(320x568)でも、ヒントで容器の位置が動かない', (tester) async {
    // この大きさでは9本が1画面に入りきらず、スクロールで見せる(従来どおり)
    await check(tester, const Size(320, 568), art: true, fullyVisible: false);
  });

  testWidgets('ヒント表示中も全部の容器が見える(360x800・画像なし)', (tester) async {
    await check(tester, const Size(360, 800), art: false);
  });
}
