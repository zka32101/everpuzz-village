import 'package:color_sort_app/game/app_state.dart';
import 'package:color_sort_app/game/transfer.dart';
import 'package:color_sort_app/l10n/strings.dart';
import 'package:color_sort_app/ui/transfer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/foundation.dart';

import 'helpers.dart';

Future<AppState> playedApp() async {
  final kv = MemoryKeyValueStore();
  final clock = FakeClock(DateTime.utc(2026, 1, 1, 12));
  await VersionedJsonStore(kv).save(
    AppState.economyKey,
    AppState.economySchema,
    EconomyState.initial(economyConfig, clock.now())
        .copyWith(coins: 300)
        .toJson(),
  );
  final app = await loadApp(kv: kv, clock: clock);
  for (var i = 0; i < 3; i++) {
    await app.recordWin(i, moves: 10, stars: 2);
  }
  await app.placeBuilding('small_house', 2);
  return app;
}

void main() {
  test('コードを作って別の端末で読み込むと、進行・コイン・町が移る', () async {
    final a = await playedApp();
    final code = await a.createTransferCode();
    expect(code.startsWith('EVP1.'), isTrue);

    final b = await loadApp();
    expect(b.clearedLevels, 0);
    expect(await b.applyTransferCode(code), isTrue);
    expect(b.clearedLevels, 3);
    expect(b.coins, a.coins);
    expect(b.townState.placementOf('small_house')!.cell, 2);
    // 保存にも反映される(再起動しても残る)
    final kv = b.kv as MemoryKeyValueStore;
    final again = await loadApp(kv: kv);
    expect(again.clearedLevels, 3);
    expect(again.townState.placementOf('small_house')!.cell, 2);
  });

  test('貼り付けで入る空白・改行があっても読める', () async {
    final a = await playedApp();
    final code = await a.createTransferCode();
    final spaced = '  ${code.substring(0, 20)}\n${code.substring(20)}  ';
    final b = await loadApp();
    expect(await b.applyTransferCode(spaced), isTrue);
    expect(b.clearedLevels, 3);
  });

  test('壊れた・別物のコードは、何も変えずに断る', () async {
    final b = await playedApp();
    final before = b.clearedLevels;
    for (final bad in [
      '',
      'hello',
      'EVP1.',
      'EVP1.!!!!',
      'EVP1.${'A' * 40}',
      TransferCodec.encode({'unknown': '{}'}),
      TransferCodec.encode({'economy': '{}'}), // 進行が無い
      TransferCodec.encode({'progress': 'not json'}),
    ]) {
      expect(await b.applyTransferCode(bad), isFalse, reason: bad);
    }
    expect(b.clearedLevels, before);
    expect(b.townState.placements, isNotEmpty);
  });

  testWidgets('引き継ぎ画面: 作る→コピー、貼る→確認→置き換え', (tester) async {
    final a = (await tester.runAsync(playedApp))!;
    final b = (await tester.runAsync(loadApp))!;
    final clip = <String?>[];
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clip.add((call.arguments as Map)['text'] as String?);
      }
      return null;
    });
    await tester.pumpWidget(L10n(
      translator: translatorFor('en'),
      child: MaterialApp(home: TransferScreen(app: a)),
    ));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('transfer-create')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.tap(find.byKey(const Key('transfer-copy')));
    await tester.pump();
    expect(clip.single, startsWith('EVP1.'));

    await tester.pumpWidget(L10n(
      translator: translatorFor('en'),
      child: MaterialApp(home: TransferScreen(app: b)),
    ));
    await tester.enterText(
        find.byKey(const Key('transfer-input')), clip.single!);
    await tester.ensureVisible(find.byKey(const Key('transfer-load')));
    await tester.tap(find.byKey(const Key('transfer-load')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('transferConfirm')), findsOneWidget);
    await tester.tap(find.byKey(const Key('transferOk')));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(b.clearedLevels, 3);
    expect(find.text('Transferred.'), findsOneWidget);
  });

  testWidgets('確認で「やめる」と、何も変わらない', (tester) async {
    final a = (await tester.runAsync(playedApp))!;
    final b = (await tester.runAsync(loadApp))!;
    final code = (await tester.runAsync(a.createTransferCode))!;
    await tester.pumpWidget(L10n(
      translator: translatorFor('en'),
      child: MaterialApp(home: TransferScreen(app: b)),
    ));
    await tester.enterText(find.byKey(const Key('transfer-input')), code);
    await tester.ensureVisible(find.byKey(const Key('transfer-load')));
    await tester.tap(find.byKey(const Key('transfer-load')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('transferCancel')));
    await tester.pumpAndSettle();
    expect(b.clearedLevels, 0);
    expect(find.byKey(const Key('transferConfirm')), findsNothing);
  });
}
