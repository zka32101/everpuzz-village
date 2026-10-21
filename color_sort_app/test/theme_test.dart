import 'package:color_sort_app/game/art.dart';
import 'package:color_sort_app/ui/tube_widget.dart';
import 'package:color_sort_app/l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => L10n(
      translator: translatorFor('en'),
      child: MaterialApp(home: Scaffold(body: Center(child: child))),
    );

void main() {
  test('テーマは12面ごとに切り替わる(若草→秋→冬→夏→桜)', () {
    const a = ArtCatalog.empty;
    expect(a.themeFor(0), 'spring');
    expect(a.themeFor(11), 'spring');
    expect(a.themeFor(12), 'autumn');
    expect(a.themeFor(24), 'winter');
    expect(a.themeFor(36), 'summer');
    expect(a.themeFor(48), 'sakura');
    expect(a.themeFor(999), 'sakura');
  });

  test('テーマ付きの画像があればそれ、無ければ共通の画像・図形', () {
    const art = ArtCatalog({
      'tube_back',
      'tube_front',
      'tube_back_autumn',
      'ball_autumn_03',
    });
    expect(art.themed('tube_back', 'autumn'), 'tube_back_autumn');
    expect(art.themed('tube_front', 'autumn'), 'tube_front'); // 秋用の手前は無い
    expect(art.themed('tube_back', 'winter'), 'tube_back');
    expect(art.ballId('autumn', 3), 'ball_autumn_03');
    expect(art.ballId('autumn', 11), 'ball_autumn_03'); // 色番号は8色で巡る
    expect(art.ballId('autumn', 4), isNull);
    expect(art.ballId('winter', 3), isNull);
  });

  testWidgets('テーマ付きの色玉でも、記号と数字はコードで描かれ、崩れない', (tester) async {
    const art = ArtCatalog({
      'tube_back',
      'tube_front',
      'ball_autumn_00',
      'ball_autumn_01',
    });
    await tester.pumpWidget(host(TubeWidget(
      index: 0,
      tube: const [0, 1, 2],
      lock: null,
      usable: true,
      selected: false,
      onTap: () {},
      art: art,
      theme: 'autumn',
    )));
    await tester.pump();
    expect(tester.takeException(), isNull);
    // 数字(色番号+1)は画像の有無によらず文字として出る
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // 画像の無い色(2)は図形
    expect(find.byType(Image), findsWidgets);
  });
}
