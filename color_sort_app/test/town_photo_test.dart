import 'dart:typed_data';

import 'package:color_sort_app/game/app_state.dart';
import 'package:color_sort_app/l10n/strings.dart';
import 'package:color_sort_app/ui/town_screen.dart';
import 'package:color_sort_app/widget/town_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/foundation.dart';

import 'helpers.dart';

Future<AppState> richApp(WidgetTester tester) async {
  final kv = MemoryKeyValueStore();
  final clock = FakeClock(DateTime.utc(2026, 1, 1, 12));
  await VersionedJsonStore(kv).save(
    AppState.economyKey,
    AppState.economySchema,
    EconomyState.initial(economyConfig, clock.now())
        .copyWith(coins: 100)
        .toJson(),
  );
  return (await tester.runAsync(() => loadApp(kv: kv, clock: clock)))!;
}

void main() {
  testWidgets('建物が無いときは共有せず、案内を出す', (tester) async {
    final app = await richApp(tester);
    var shared = 0;
    await tester.pumpWidget(L10n(
      translator: translatorFor('en'),
      child: MaterialApp(
        home: TownScreen(
          app: app,
          sharePhoto: (png, text) async => shared++,
          loadImage: (_) async => null,
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('town-share')));
    await tester.pump();
    await tester.pump();
    expect(shared, 0);
    expect(find.textContaining('Place a building'), findsOneWidget);
  });

  testWidgets('建物があると、町のPNGと一言を共有窓口に渡す', (tester) async {
    final app = await richApp(tester);
    await tester.runAsync(() => app.placeBuilding('small_house', 0));
    Uint8List? gotPng;
    String? gotText;
    await tester.pumpWidget(L10n(
      translator: translatorFor('en'),
      child: MaterialApp(
        home: TownScreen(
          app: app,
          sharePhoto: (png, text) async {
            gotPng = png;
            gotText = text;
          },
          loadImage: (_) async => null,
        ),
      ),
    ));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('town-share')));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    expect(gotPng, isNotNull);
    expect(gotPng!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    expect(gotText, 'This is my town.');
  });

  testWidgets('町の写真は建物が無いと作らない', (tester) async {
    final app = await richApp(tester);
    expect(
        await tester
            .runAsync(() => renderTownPhoto(app, loadImage: (_) async => null)),
        isNull);
  });
}
