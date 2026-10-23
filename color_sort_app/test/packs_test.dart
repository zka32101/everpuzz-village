import 'package:color_sort_app/game/app_state.dart';
import 'package:color_sort_app/game/purchases.dart';
import 'package:color_sort_app/l10n/strings.dart';
import 'package:color_sort_app/ui/level_select_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/foundation.dart';

import 'helpers.dart';

Future<void> clearAll(AppState app, int packIndex) async {
  final n = app.packs[packIndex].pack.levels.length;
  final saved = app.activePackIndex;
  app.activePackIndex = packIndex;
  for (var i = 0; i < n; i++) {
    await app.recordWin(i, moves: 10, stars: 1);
  }
  app.activePackIndex = saved;
}

class _Shop implements PurchaseGate {
  final owned = <String>{};

  @override
  Future<Map<String, String>> prices(Iterable<String> ids) async =>
      {for (final id in ids) id: '¥960'};

  @override
  Future<BuyResult> buy(String productId) async {
    owned.add(productId);
    return const BuyResult(BuyStatus.success, transactionId: 'tx-pack');
  }

  @override
  Future<bool> restore() async => false;

  @override
  Future<bool> adsRemoved() async => false;

  @override
  Future<Set<String>> ownedProducts() async => {...owned};
}

void main() {
  test('パックの一覧が読め、2つ目は最初は遊べない(前のパックを全部クリアすると解放)', () async {
    final app = await loadApp();
    expect(app.packs.map((p) => p.id), ['main', 'extra1', 'extra2', 'extra3']);
    expect(app.packs[0].pack.levels, hasLength(60));
    expect(app.packs[1].pack.levels, hasLength(60));
    expect(app.packs[1].pack.validate(), isEmpty); // 解けない面は無い
    expect(app.isPackAvailable(0), isTrue);
    expect(app.isPackAvailable(1), isFalse);
    expect(app.packLockReason(1), 'previous');
    expect(await app.selectPack(1), isFalse);
    expect(app.activePackIndex, 0);

    await clearAll(app, 0);
    expect(app.isPackAvailable(1), isTrue);
    expect(app.packLockReason(1), isNull);
    expect(app.clearedLevels, 60);
    expect(await app.selectPack(1), isTrue);
    expect(app.activePackIndex, 1);
    expect(app.pack.packId, 'extra1');
  });

  test('面のIDはパックごとに別で、進行は混ざらない', () async {
    final app = await loadApp();
    final ids = [for (final p in app.packs) ...p.pack.levels.map((l) => l.id)];
    expect(ids.toSet(), hasLength(240));
    await clearAll(app, 0);
    await app.selectPack(1);
    expect(app.clearedIn(0), 60);
    expect(app.clearedIn(1), 0);
    expect(app.nextLevelIndex, 0);
    await app.recordWin(0, moves: 10, stars: 1);
    expect(app.clearedIn(1), 1);
    expect(app.clearedLevels, 61); // 町の解放・マス数は全パックの合計
    expect(app.nextLevelIndex, 1);
  });

  test('行き来は自由: クリア済みの面と次の面は遊べ、先の面は遊べない。戻ってもやり直せる', () async {
    final app = await loadApp();
    for (var i = 0; i < 5; i++) {
      await app.recordWin(i, moves: 10, stars: 1);
    }
    expect(app.nextLevelIndex, 5);
    for (var i = 0; i <= 5; i++) {
      expect(app.isUnlocked(i), isTrue, reason: '$i');
    }
    expect(app.isUnlocked(6), isFalse);
    // 戻って遊び直しても、次の面は動かない
    await app.recordWin(2, moves: 8, stars: 3);
    expect(app.nextLevelIndex, 5);
  });

  test('「あそぶ」の行き先: 終えたパックの次の遊べるパックへ進む。全部クリア済みなら最後の面', () async {
    final app = await loadApp();
    expect(await app.advanceToPlayable(), 0);
    expect(app.activePackIndex, 0);
    await clearAll(app, 0);
    expect(app.nextAvailablePack, 1);
    expect(await app.advanceToPlayable(), 0);
    expect(app.activePackIndex, 1);
    await clearAll(app, 1);
    expect(app.nextAvailablePack, 2);
    expect(await app.advanceToPlayable(), 0);
    expect(app.activePackIndex, 2);
    await clearAll(app, 2);
    expect(app.nextAvailablePack, isNull);
    expect(await app.advanceToPlayable(), 59);
  });

  test('選んだパックは保存され、再起動しても戻る', () async {
    final kv = MemoryKeyValueStore();
    final app = await loadApp(kv: kv);
    await clearAll(app, 0);
    await app.selectPack(1);
    final again = await loadApp(kv: kv);
    expect(again.activePackIndex, 1);
    expect(again.pack.packId, 'extra1');
  });

  test('パックに必要な中身(requires)があれば、持っていないと遊べない', () async {
    final base = await loadApp();
    final app = AppState(
      packs: [
        base.packs[0],
        PackInfo(
            id: 'paid',
            pack: base.packs[1].pack,
            requires: 'levels.paid',
            unlockAfterPrevious: false),
      ],
      kv: base.kv,
      progress: base.progress,
      economyState: base.current,
      townConfig: base.townConfig,
    );
    expect(app.isPackAvailable(1), isFalse);
    expect(app.packLockReason(1), 'purchase');
  });

  test('追加の面パック(チャプター4)は買うまで遊べず、買えば前章を終えていなくても遊べる', () async {
    final gate = _Shop();
    final app = await loadApp(purchaseGate: gate);
    expect(app.packs[3].id, 'extra3');
    expect(app.packs[3].pack.levels, hasLength(60));
    expect(app.packs[3].pack.validate(), isEmpty); // 解けない面は無い
    expect(app.packLockReason(3), 'purchase');
    expect(app.isPackAvailable(3), isFalse);
    expect(app.shopProducts.map((p) => p.id), contains('levels_pack_1'));
    // 買う前は、無料の章を全部クリアしても開かない
    for (var i = 0; i < 3; i++) {
      await clearAll(app, i);
    }
    expect(app.isPackAvailable(3), isFalse);
    expect(app.nextAvailablePack, isNull);

    expect(await app.buyProduct('levels_pack_1'), isTrue);
    expect(app.owns('levels.extra3'), isTrue);
    expect(app.isPackAvailable(3), isTrue);
    expect(await app.selectPack(3), isTrue);
    expect(app.pack.packId, 'extra3');
  });

  test('買ってすぐ(前の章を遊ぶ前でも)チャプター4を遊べる', () async {
    final gate = _Shop();
    final app = await loadApp(purchaseGate: gate);
    expect(await app.buyProduct('levels_pack_1'), isTrue);
    expect(app.isPackAvailable(3), isTrue); // 前章の全クリアは求めない
    expect(app.isPackAvailable(1), isFalse); // 無料の章は従来どおり順番に
  });

  testWidgets('面選択にチャプターの切り替えが出る。遊べないものは鍵つきで押せない', (tester) async {
    final app = (await tester.runAsync(loadApp))!;
    await tester.pumpWidget(L10n(
      translator: translatorFor('en'),
      child: MaterialApp(home: LevelSelectScreen(app: app)),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pack-main')), findsOneWidget);
    expect(find.byKey(const Key('pack-extra1')), findsOneWidget);
    expect(find.textContaining('Clear the previous chapter'), findsNWidgets(2));
    await tester.tap(find.byKey(const Key('pack-extra1')));
    await tester.pumpAndSettle();
    expect(app.activePackIndex, 0); // 押せない

    await tester.runAsync(() => clearAll(app, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pack-extra1')));
    await tester.pumpAndSettle();
    expect(app.activePackIndex, 1);
    expect(find.byKey(const Key('level-0')), findsOneWidget);
    // 戻れる
    await tester.tap(find.byKey(const Key('pack-main')));
    await tester.pumpAndSettle();
    expect(app.activePackIndex, 0);
  });
}
