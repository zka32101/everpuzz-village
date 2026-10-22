import 'dart:ui' as ui;

import 'package:color_sort/color_sort.dart' show Placement;
import 'package:color_sort_app/game/art.dart';
import 'package:color_sort_app/widget/home_widget_sync.dart';
import 'package:color_sort_app/widget/town_snapshot.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('町の絵は、中身が同じなら同じ印、変われば別の印', () {
    const a = TownSnapshot(
        placements: [Placement(buildingId: 'house', cell: 0)], cells: 8);
    const b = TownSnapshot(
        placements: [Placement(buildingId: 'house', cell: 0, stage: 2)],
        cells: 8);
    expect(a.signature, a.signature);
    expect(a.signature, isNot(b.signature));
  });

  testWidgets('画像が無くてもPNGができる(淡い四角と背景色)', (tester) async {
    const snap = TownSnapshot(
        placements: [Placement(buildingId: 'house', cell: 1)], cells: 8);
    final png = await tester.runAsync(
        () => snap.render((_) async => null, art: const ArtCatalog({})));
    expect(png, isNotNull);
    // PNG のしるし
    expect(png!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  testWidgets('渡すのは中身が変わった時だけ。端末側が無くても落ちない', (tester) async {
    final app = (await tester.runAsync(loadApp))!;
    final calls = <MethodCall>[];
    const ch = MethodChannel('test/home_widget');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, (c) async {
      calls.add(c);
      return null;
    });
    final sync = HomeWidgetSync(app,
        channel: ch,
        loadImage: (_) async => null as ui.Image?,
        debounce: Duration.zero);
    expect(await tester.runAsync(sync.sync), isTrue);
    expect(calls.single.method, 'update');
    expect(await tester.runAsync(sync.sync), isFalse); // 変わっていない
    expect(calls, hasLength(1));

    // 端末側が未対応(ハンドラ無し)でも例外にならない
    final none = HomeWidgetSync(app,
        channel: const MethodChannel('test/none'),
        loadImage: (_) async => null,
        debounce: Duration.zero);
    expect(await tester.runAsync(none.sync), isFalse);
  });
}
