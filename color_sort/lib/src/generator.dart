import 'dart:math';

import 'package:puzzle_core/puzzle.dart';

import 'rules.dart';

/// 面の仕様(難易度カーブの1点)。
class LevelParams {
  const LevelParams({
    required this.colors,
    required this.empties,
    required this.scrambleSteps,
    this.locks = const [],
  });

  final int colors;
  final int empties;
  final int scrambleSteps;

  /// 導入する特殊容器の種類(位置・解錠色は生成時にシードで決める)。
  final List<LockKind> locks;
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
                  : n <= 45
                      ? 7
                      : 8;
  var steps = 20 + n * 3;
  // 特殊容器は31面目から段階導入(鍵 → 凍結 → 両方)。ご褒美面にはなし。
  var locks = <LockKind>[];
  if (n > 30) {
    locks = switch (n % 4) {
      1 => [LockKind.key],
      3 => [LockKind.frozen],
      0 when n > 45 => [LockKind.key, LockKind.frozen],
      _ => [],
    };
  }
  if (n % 7 == 0) {
    colors = max(3, colors - 1);
    steps = 15;
    locks = [];
  }
  // 31面目から空容器1本の面(3面に1回)を混ぜて難しくする。
  // 特殊容器の面は空容器1本だと解けない(検証済み)ので2本のまま。
  final empties = n > 30 && n % 3 == 0 && locks.isEmpty ? 1 : 2;
  return LevelParams(
    colors: colors,
    empties: empties,
    scrambleSteps: steps,
    locks: locks,
  );
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

/// 特殊容器を決める。ばらした後の盤面で、中身のある容器にだけ付ける
/// (位置・解錠色はシード固定)。解けるかは呼び出し側がソルバーで確認する。
List<TubeLock?> placeLocks(LevelParams p, Tubes tubes, int seed) {
  final rnd = Random(seed ^ 0x5eed);
  final locks = List<TubeLock?>.filled(tubes.length, null);
  final candidates = [
    for (var i = 0; i < tubes.length; i++)
      if (tubes[i].isNotEmpty) i
  ]..shuffle(rnd);
  for (final kind in p.locks) {
    final i = candidates.removeLast();
    locks[i] = kind == LockKind.key
        ? TubeLock.key(rnd.nextInt(p.colors))
        : const TubeLock.frozen();
  }
  return locks;
}

class GeneratedLevel {
  const GeneratedLevel(this.seed, this.spec, this.result);

  final int seed;
  final Map<String, Object?> spec;
  final SolveResult<Move> result;
}

/// 生成・出荷前検証で共通の探索上限(同じ値を使わないと検証で落ちる面が出る)。
const levelSolveMaxStates = 300000;

/// 面番号から決定的に面を作る。同じ index なら全端末で同じ面。
/// 解けて、かつ最短手数が [minMoves] 以上の面が出るまで派生シードで再試行する。
GeneratedLevel generateLevel(
  int index, {
  int baseSeed = 20261019,
  int minMoves = 6,
  int maxStates = levelSolveMaxStates,
  int maxAttempts = 200,
}) {
  final p = paramsForIndex(index);
  const rules = ColorSortRules();
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    final seed = baseSeed + index * 1000 + attempt;
    final tubes = scramble(p, seed);
    final locks = placeLocks(p, tubes, seed);
    final spec = <String, Object?>{
      'capacity': ColorSortRules.capacity,
      'tubes': tubes,
      if (locks.any((l) => l != null))
        'locks': [for (final l in locks) l?.toJson()],
    };
    final r = solve(rules, spec, maxStates: maxStates);
    if (r.solvable && r.conclusive && (r.minMoves ?? 0) >= minMoves) {
      return GeneratedLevel(seed, spec, r);
    }
  }
  throw StateError('面 $index を生成できなかった');
}
