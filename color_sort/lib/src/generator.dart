import 'dart:math';

import 'package:puzzle_core/puzzle.dart';

import 'rules.dart';

/// 面の仕様(難易度カーブの1点)。
class LevelParams {
  const LevelParams({
    required this.colors,
    required this.empties,
    required this.scrambleSteps,
  });

  final int colors;
  final int empties;
  final int scrambleSteps;
}

/// 難易度カーブ(設計 §4)。index は 0 始まり。7面ごとにご褒美面(易しい)。
LevelParams paramsForIndex(int index) {
  final n = index + 1;
  var colors = n <= 5
      ? 3
      : n <= 10
          ? 4
          : n <= 20
              ? 5
              : n <= 30
                  ? 6
                  : 7;
  var steps = 20 + n * 3;
  if (n % 7 == 0) {
    colors = max(3, colors - 1);
    steps = 15;
  }
  return LevelParams(colors: colors, empties: 2, scrambleSteps: steps);
}

/// 完成状態から単位を1つずつ動かしてばらす。
/// 逆操作は合法とは限らないため、解けるかは必ずソルバーで検証する(これを正とする)。
Tubes scramble(LevelParams p, int seed) {
  final rnd = Random(seed);
  final tubes = <List<int>>[
    for (var c = 0; c < p.colors; c++)
      List<int>.filled(ColorSortRules.capacity, c, growable: true),
    for (var e = 0; e < p.empties; e++) <int>[],
  ];
  for (var i = 0; i < p.scrambleSteps * 4; i++) {
    final from = [
      for (var t = 0; t < tubes.length; t++)
        if (tubes[t].isNotEmpty) t
    ];
    final a = from[rnd.nextInt(from.length)];
    final to = [
      for (var t = 0; t < tubes.length; t++)
        if (t != a && tubes[t].length < ColorSortRules.capacity) t
    ];
    final b = to[rnd.nextInt(to.length)];
    tubes[b].add(tubes[a].removeLast());
  }
  return tubes;
}

class GeneratedLevel {
  const GeneratedLevel(this.seed, this.spec, this.result);

  final int seed;
  final Map<String, Object?> spec;
  final SolveResult<Move> result;
}

/// 面番号から決定的に面を作る。同じ index なら全端末で同じ面。
/// 解けて、かつ最短手数が [minMoves] 以上の面が出るまで派生シードで再試行する。
GeneratedLevel generateLevel(
  int index, {
  int baseSeed = 20261019,
  int minMoves = 6,
  int maxStates = 300000,
  int maxAttempts = 200,
}) {
  final p = paramsForIndex(index);
  const rules = ColorSortRules();
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    final seed = baseSeed + index * 1000 + attempt;
    final spec = <String, Object?>{
      'capacity': ColorSortRules.capacity,
      'tubes': scramble(p, seed),
    };
    final r = solve(rules, spec, maxStates: maxStates);
    if (r.solvable && r.conclusive && (r.minMoves ?? 0) >= minMoves) {
      return GeneratedLevel(seed, spec, r);
    }
  }
  throw StateError('面 $index を生成できなかった');
}
