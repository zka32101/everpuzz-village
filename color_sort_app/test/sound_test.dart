import 'package:color_sort/color_sort.dart';
import 'package:color_sort_app/game/app_state.dart';
import 'package:color_sort_app/game/hint.dart';
import 'package:color_sort_app/game/sound.dart';
import 'package:color_sort_app/l10n/strings.dart';
import 'package:color_sort_app/ui/menu.dart';
import 'package:color_sort_app/ui/play_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/foundation.dart';

import 'helpers.dart';

class RecordingSound implements SoundPlayer {
  final played = <Sfx>[];

  @override
  Future<void> play(Sfx sfx) async => played.add(sfx);
}

void main() {
  test('建物を置くと「置く」音、贈り物で「コイン」音。オフなら鳴らない', () async {
    final sound = RecordingSound();
    final kv = MemoryKeyValueStore();
    final clock = FakeClock(DateTime.utc(2026, 1, 1, 12));
    await VersionedJsonStore(kv).save(
      AppState.economyKey,
      AppState.economySchema,
      EconomyState.initial(economyConfig, clock.now())
          .copyWith(coins: 100)
          .toJson(),
    );
    final app = await loadApp(kv: kv, clock: clock, sound: sound);
    await app.placeBuilding('small_house', 0);
    expect(sound.played, [Sfx.place]);
    await app.claimGift();
    expect(sound.played, [Sfx.place, Sfx.coin]);

    await app.setSoundOn(false);
    await app.upgradeBuilding('small_house');
    expect(sound.played, hasLength(2)); // 増えない

    // 設定は保存され、再起動しても残る
    final again = await loadApp(kv: kv, clock: clock, sound: sound);
    expect(again.soundOn, isFalse);
  });

  testWidgets('面の画面: えらぶ=選ぶ音、うつす=注ぐ音、クリア=クリア音', (tester) async {
    final sound = RecordingSound();
    final app = (await tester.runAsync(() => loadApp(sound: sound)))!;
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(L10n(
      translator: translatorFor('en'),
      child: MaterialApp(home: PlayScreen(app: app, index: 0)),
    ));
    await tester.pump();
    final board = const ColorSortRules().initial(app.pack.levels[0].spec);
    final m = solveHint(board)!;
    await tester.tap(find.byKey(Key('tube-${m.$1}')));
    await tester.pump();
    expect(sound.played, [Sfx.select]);
    await tester.tap(find.byKey(Key('tube-${m.$2}')));
    await tester.pump();
    expect(sound.played, [Sfx.select, Sfx.pour]);

    // 最後まで解くと、最後に「クリア」の音が鳴る(その手の注ぐ音は鳴らさない)
    var b = const ColorSortRules().apply(board, m);
    final rules = const ColorSortRules();
    while (!rules.isWon(b)) {
      final next = solveHint(b)!;
      await tester.tap(find.byKey(Key('tube-${next.$1}')));
      await tester.pump();
      await tester.tap(find.byKey(Key('tube-${next.$2}')));
      await tester.pump();
      b = rules.apply(b, next);
    }
    await tester.pump(const Duration(seconds: 1));
    expect(sound.played.last, Sfx.win);
    expect(sound.played.where((s) => s == Sfx.win), hasLength(1));
  });

  testWidgets('設定の「効果音」で切り替えられる', (tester) async {
    final app = (await tester.runAsync(loadApp))!;
    await tester.pumpWidget(L10n(
      translator: translatorFor('en'),
      child: MaterialApp(home: SettingsScreen(app: app)),
    ));
    expect(app.soundOn, isTrue);
    await tester.tap(find.byKey(const Key('setting-sound')));
    await tester.pump();
    expect(app.soundOn, isFalse);
  });
}
