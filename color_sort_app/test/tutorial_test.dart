import 'package:color_sort_app/ui/menu.dart';
import 'package:color_sort_app/ui/town_screen.dart';
import 'package:color_sort_app/l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/foundation.dart';

import 'helpers.dart';

void main() {
  testWidgets('はじめて起動すると案内が出て、最後まで見ると町へ進み、次からは出ない', (tester) async {
    final kv = MemoryKeyValueStore();
    final app =
        (await tester.runAsync(() => loadApp(kv: kv, showTutorial: true)))!;
    expect(app.tutorialSeen, isFalse);
    await tester.pumpWidget(appWidget(app, town: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tutorial-pages')), findsOneWidget);
    expect(find.text('1/4'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('tutorial-next')));
      await tester.pumpAndSettle();
    }
    expect(find.text('4/4'), findsOneWidget);
    expect(find.byKey(const Key('tutorial-skip')), findsNothing); // 最後は「はじめる」だけ
    await tester.tap(find.byKey(const Key('tutorial-done')));
    await tester.pumpAndSettle();
    expect(find.byType(TownScreen), findsOneWidget);
    expect(app.tutorialSeen, isTrue);
    // 再起動しても出ない
    final again =
        (await tester.runAsync(() => loadApp(kv: kv, showTutorial: true)))!;
    expect(again.tutorialSeen, isTrue);
  });

  testWidgets('とばせる。とばしても「見た」になる', (tester) async {
    final app = (await tester.runAsync(() => loadApp(showTutorial: true)))!;
    await tester.pumpWidget(appWidget(app, town: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tutorial-skip')));
    await tester.pumpAndSettle();
    expect(find.byType(TownScreen), findsOneWidget);
    expect(app.tutorialSeen, isTrue);
  });

  testWidgets('設定の「あそびかた」から見直せて、閉じると設定に戻る', (tester) async {
    final app = (await tester.runAsync(loadApp))!;
    await tester.pumpWidget(L10n(
      translator: translatorFor('en'),
      child: MaterialApp(home: SettingsScreen(app: app)),
    ));
    await tester.tap(find.byKey(const Key('setting-tutorial')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tutorial-pages')), findsOneWidget);
    await tester.tap(find.byKey(const Key('tutorial-skip')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });
}
