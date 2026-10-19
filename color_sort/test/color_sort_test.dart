import 'package:color_sort/color_sort.dart';
import 'package:puzzle_core/puzzle_core.dart';
import 'package:test/test.dart';

Map<String, Object?> spec(Tubes t) => {'capacity': 4, 'tubes': t};

void main() {
  const rules = ColorSortRules();

  test('移し替えは上の同色の塊をまとめて、空きの範囲で動かす', () {
    final s = rules.initial(spec([
      [1, 0, 0],
      [0, 0],
      []
    ]));
    final next = rules.apply(s, (0, 1));
    expect(next, [
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

  test('生成した60面はすべて解け、最短手数が基準以上', () {
    for (var i = 0; i < 60; i++) {
      final g = generateLevel(i);
      expect(g.result.solvable, isTrue, reason: 'level $i');
      expect(g.result.minMoves, greaterThanOrEqualTo(6), reason: 'level $i');
      expect(replayWins(rules, g.spec, g.result.solution!), isTrue,
          reason: 'level $i');
    }
  });

  test('難易度カーブ: 31面目以降は7〜8色で、空容器1本の面が混ざる', () {
    expect(paramsForIndex(35).colors, 7);
    expect(paramsForIndex(50).colors, 8);
    expect([for (var i = 30; i < 60; i++) paramsForIndex(i).empties].toSet(),
        {1, 2});
    expect(
        [for (var i = 0; i < 30; i++) paramsForIndex(i).empties].toSet(), {2});
  });

  test('難易度カーブ: 色数は単調(ご褒美面を除く)で、ご褒美面は易しい', () {
    expect(paramsForIndex(0).colors, 3);
    expect(paramsForIndex(10).colors, 5);
    expect(paramsForIndex(6).colors, lessThan(paramsForIndex(5).colors + 1));
    expect(paramsForIndex(6).scrambleSteps,
        lessThan(paramsForIndex(5).scrambleSteps));
  });
}
