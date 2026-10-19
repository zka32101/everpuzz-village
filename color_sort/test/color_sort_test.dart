import 'dart:math';

import 'package:color_sort/color_sort.dart';
import 'package:puzzle_core/puzzle_core.dart';
import 'package:test/test.dart';

Map<String, Object?> spec(Tubes t, [List<Map<String, Object?>?>? locks]) =>
    {'capacity': 4, 'tubes': t, if (locks != null) 'locks': locks};

void main() {
  const rules = ColorSortRules();

  test('移し替えは上の同色の塊をまとめて、空きの範囲で動かす', () {
    final s = rules.initial(spec([
      [1, 0, 0],
      [0, 0],
      []
    ]));
    final next = rules.apply(s, (0, 1));
    expect(next.tubes, [
      [1],
      [0, 0, 0, 0],
      []
    ]);
  });

  test('色違いの上には置けない・満杯には置けない', () {
    final s = rules.initial(spec([
      [0, 1],
      [1, 0],
      [0, 0, 0, 0]
    ]));
    expect(rules.legalMoves(s), isNot(contains((0, 1))));
    expect(rules.legalMoves(s).where((m) => m.$2 == 2), isEmpty);
  });

  test('勝敗判定', () {
    expect(
        rules.isWon(rules.initial(spec([
          [0, 0, 0, 0],
          [1, 1, 1, 1],
          []
        ]))),
        isTrue);
    expect(
        rules.isWon(rules.initial(spec([
          [0, 0, 0],
          [1, 1, 1, 1],
          [0]
        ]))),
        isFalse);
  });

  test('面生成は決定的(同じ面番号→同じ面)', () {
    final a = generateLevel(3);
    final b = generateLevel(3);
    expect(a.spec, b.spec);
    expect(a.seed, b.seed);
  });

  test('生成面は解け、最短手数が基準以上(特殊容器の面を含む代表。全60面は check_levels で検証)', () {
    // 0〜29面は全て、31面目以降は 凍結(30)・鍵(32,36)・両方(47) の代表を確認する。
    for (final i in [...List.generate(30, (i) => i), 30, 32, 36, 47]) {
      final g = generateLevel(i);
      expect(g.result.solvable, isTrue, reason: 'level $i');
      expect(g.result.minMoves, greaterThanOrEqualTo(6), reason: 'level $i');
      expect(replayWins(rules, g.spec, g.result.solution!), isTrue,
          reason: 'level $i');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('難易度カーブ: 31面目以降は7〜8色で、空容器1本の面が混ざる', () {
    expect(paramsForIndex(35).colors, 7);
    expect(paramsForIndex(50).colors, 8);
    expect({for (var i = 30; i < 60; i++) paramsForIndex(i).empties}, {1, 2});
    expect({for (var i = 0; i < 30; i++) paramsForIndex(i).empties}, {2});
  });

  test('難易度カーブ: 色数は単調(ご褒美面を除く)で、ご褒美面は易しい', () {
    expect(paramsForIndex(0).colors, 3);
    expect(paramsForIndex(10).colors, 5);
    expect(paramsForIndex(6).colors, lessThan(paramsForIndex(5).colors + 1));
    expect(paramsForIndex(6).scrambleSteps,
        lessThan(paramsForIndex(5).scrambleSteps));
  });

  group('特殊容器', () {
    test('鍵付き: 指定色が1本そろうまで移し元にも移し先にもできない', () {
      // 容器1が鍵付き(色0)。容器0は色0が3つ+色1。
      final locked = rules.initial(spec([
        [0, 0, 0, 1],
        [1, 1],
        [],
        [0],
      ], [
        null,
        {'kind': 'key', 'color': 0},
        null,
        null,
      ]));
      expect(rules.legalMoves(locked).where((m) => m.$1 == 1 || m.$2 == 1),
          isEmpty);
      // 色0が1本そろう(容器 0 が [0,0,0,0] になる)と使える。
      final solved = Board([
        [0, 0, 0, 0],
        [1, 1],
        [],
        [],
      ], locked.locks);
      expect(solved.isUsable(1), isTrue);
    });

    test('凍結: 隣の容器がそろうまで使えず、そろうと解凍される', () {
      final b = rules.initial(spec([
        [0, 0, 0],
        [1, 0],
        [1, 1, 1, 1],
      ], [
        null,
        {'kind': 'frozen'},
        null,
      ]));
      // 容器2が完成 → 隣の容器1は解凍済み。
      expect(b.isUsable(1), isTrue);
      final frozen = rules.initial(spec([
        [0, 0, 0],
        [1, 0],
        [1, 1, 1],
      ], [
        null,
        {'kind': 'frozen'},
        null,
      ]));
      expect(frozen.isUsable(1), isFalse);
      expect(rules.legalMoves(frozen).where((m) => m.$1 == 1 || m.$2 == 1),
          isEmpty);
    });

    test('凍結がある面では容器の位置が区別され、鍵だけなら入れ替えを同一視する', () {
      final a = rules.initial(spec([
        [0],
        [1]
      ], [
        null,
        {'kind': 'frozen'}
      ]));
      final b = Board([a.tubes[1], a.tubes[0]], a.locks);
      expect(rules.hash(a), isNot(rules.hash(b)));
      final plain = rules.initial(spec([
        [0],
        [1]
      ]));
      final swapped = Board([plain.tubes[1], plain.tubes[0]], plain.locks);
      expect(rules.hash(plain), rules.hash(swapped));
      final keyed = rules.initial(spec([
        [0],
        [1]
      ], [
        null,
        {'kind': 'key', 'color': 0}
      ]));
      // 鍵付き容器は種類ごと中身と一緒に動くので、並べ替えても同じ状態。
      final keyedSwapped = Board(
          [keyed.tubes[1], keyed.tubes[0]], [keyed.locks[1], keyed.locks[0]]);
      expect(rules.hash(keyed), rules.hash(keyedSwapped));
    });

    test('解けない特殊容器配置は解なしと確定する', () {
      // 鍵の色(2)が盤面に存在しないので永遠に解錠されない。
      final r = solve(
          rules,
          spec([
            [0, 0, 0],
            [0],
            [1, 1, 1, 1],
            [],
          ], [
            null,
            {'kind': 'key', 'color': 2},
            null,
            null,
          ]));
      expect(r.solvable, isFalse);
      expect(r.conclusive, isTrue);
    });

    test('31面目以降に鍵・凍結・両方が導入され、30面目まではなし', () {
      expect(
          [for (var i = 0; i < 30; i++) paramsForIndex(i).locks]
              .expand((l) => l),
          isEmpty);
      final kinds = {
        for (var i = 30; i < 60; i++) ...paramsForIndex(i).locks,
      };
      expect(kinds, {LockKind.key, LockKind.frozen});
      expect(
          [for (var i = 30; i < 60; i++) paramsForIndex(i).locks.length]
              .reduce(max),
          2);
    });

    test('特殊容器の面は空容器2本(1本だと解けない)', () {
      for (var i = 30; i < 60; i++) {
        final p = paramsForIndex(i);
        if (p.locks.isNotEmpty) expect(p.empties, 2, reason: 'level $i');
      }
    });

    test('生成面の特殊容器はJSONに書け、再生成しても同じ', () {
      final i = [for (var i = 30; i < 60; i++) i]
          .firstWhere((i) => paramsForIndex(i).locks.isNotEmpty);
      final g = generateLevel(i);
      expect(g.spec['locks'], isNotNull);
      expect(generateLevel(i).spec, g.spec);
      expect(rules.initial(g.spec).hasLocks, isTrue);
    });
  });
}
