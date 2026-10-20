import 'package:color_sort_app/l10n/strings.dart';
import 'package:color_sort_app/ui/play_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// 面の画面は、容器が全部、1画面に収まる(下段が切れない)。
/// 容器5本(上3・下2)でも、標準の画面(360x800)で、スクロールせずに全部見える。
void main() {
  Widget play(app) => L10n(
        translator: translatorFor('en'),
        child: MaterialApp(home: PlayScreen(app: app, index: 0)),
      );

  Future<void> expectAllTubesVisible(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final app = await tester.runAsync(() => loadApp()) as dynamic;
    await tester.pumpWidget(play(app));
    await tester.pump();
    var count = 0;
    while (find.byKey(Key('tube-$count')).evaluate().isNotEmpty) {
      count++;
    }
    expect(count, greaterThanOrEqualTo(5), reason: '容器の本数');
    final screen = Offset.zero & size;
    for (var i = 0; i < count; i++) {
      final r = tester.getRect(find.byKey(Key('tube-$i')));
      expect(screen.contains(r.topLeft) && screen.contains(r.bottomRight), isTrue,
          reason: '容器 $i が画面の外にはみ出す: $r (画面 $size)');
    }
  }

  testWidgets('標準の画面で、容器が全部収まる(360x800)', (tester) async {
    await expectAllTubesVisible(tester, const Size(360, 800));
  });

  testWidgets('小さめの画面でも、容器が全部収まる(320x568)', (tester) async {
    await expectAllTubesVisible(tester, const Size(320, 568));
  });
}
