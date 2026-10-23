import 'package:color_sort_app/game/app_state.dart';
import 'package:color_sort_app/game/art.dart';
import 'package:flutter/services.dart';
import 'package:color_sort_app/l10n/strings.dart';
import 'package:color_sort_app/ui/play_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// 面が増えて容器が増えても、全部の面で容器が1画面に収まる。画面を横にして戻しても同じ。
void main() {
  Future<int> tubeCount(WidgetTester tester) async {
    var n = 0;
    while (find.byKey(Key('tube-$n')).evaluate().isNotEmpty) {
      n++;
    }
    return n;
  }

  void expectAllInside(WidgetTester tester, int count, Size size, String why) {
    final screen = Offset.zero & size;
    for (var i = 0; i < count; i++) {
      final r = tester.getRect(find.byKey(Key('tube-$i')));
      expect(
          screen.contains(r.topLeft) && screen.contains(r.bottomRight), isTrue,
          reason: '$why: 容器 $i がはみ出す $r (画面 $size)');
    }
  }

  Future<void> show(WidgetTester tester, AppState app, int index) async {
    await tester.pumpWidget(L10n(
      translator: translatorFor('en'),
      child: MaterialApp(home: PlayScreen(app: app, index: index)),
    ));
    await tester.pump();
  }

  for (final size in const [Size(390, 800), Size(360, 640)]) {
    testWidgets(
        '全ての面で、縦の画面(${size.width.toInt()}x${size.height.toInt()})に容器が全部収まる(実際の画像つき)',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final art = (await tester.runAsync(() => ArtCatalog.load(rootBundle)))!;
      final app = (await tester.runAsync(() => loadApp(art: art)))!;
      for (var p = 0; p < app.packs.length; p++) {
        app.activePackIndex = p;
        for (var i = 0; i < app.packs[p].pack.levels.length; i += 3) {
          await show(tester, app, i);
          final n = await tubeCount(tester);
          expectAllInside(tester, n, size, '${app.packs[p].id}#$i');
        }
      }
    });
  }

  testWidgets('画面を横にして縦に戻しても、容器が全部見える', (tester) async {
    final app = (await tester.runAsync(loadApp))!;
    app.activePackIndex = 2;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(390, 800);
    await show(tester, app, 59);
    final n = await tubeCount(tester);
    expectAllInside(tester, n, const Size(390, 800), '縦');
    tester.view.physicalSize = const Size(800, 390);
    await tester.pump();
    await tester.pump();
    tester.view.physicalSize = const Size(390, 800);
    await tester.pump();
    await tester.pump();
    expect(await tubeCount(tester), n);
    expectAllInside(tester, n, const Size(390, 800), '縦に戻した後');
  });

  testWidgets('横向き(800x360)や文字を大きくした画面でも、容器が全部1画面に収まる', (tester) async {
    final art = (await tester.runAsync(() => ArtCatalog.load(rootBundle)))!;
    final app = (await tester.runAsync(() => loadApp(art: art)))!;
    app.activePackIndex = 2;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final (size, scale) in [
      (const Size(800, 360), 1.0),
      (const Size(390, 800), 2.0),
      (const Size(360, 640), 1.6),
    ]) {
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      await show(tester, app, 59);
      final n = await tubeCount(tester);
      expectAllInside(tester, n, size, '$size x$scale');
    }
  });

  testWidgets('どの言語でも(文言が長くても)、小さい画面で盤面が1画面に収まる', (tester) async {
    final art = (await tester.runAsync(() => ArtCatalog.load(rootBundle)))!;
    final app = (await tester.runAsync(() => loadApp(art: art)))!;
    app.activePackIndex = 2;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    const size = Size(360, 640);
    tester.view.physicalSize = size;
    for (final lang in supportedLocales) {
      await tester.pumpWidget(L10n(
        translator: translatorFor(lang),
        child: MaterialApp(home: PlayScreen(app: app, index: 59)),
      ));
      await tester.pump();
      final n = await tubeCount(tester);
      expectAllInside(tester, n, size, lang);
      // 下のボタン(4つ)も、画面の中に収まる
      for (final key in ['undo', 'restart', 'hint', 'extraTube']) {
        final r = tester.getRect(find.byKey(Key(key)));
        expect(
            (Offset.zero & size).contains(r.topLeft) &&
                (Offset.zero & size).contains(r.bottomRight),
            isTrue,
            reason: '$lang: ボタン $key が画面外 $r');
      }
    }
  });
}
