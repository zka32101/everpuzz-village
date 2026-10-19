import 'dart:isolate';

import 'package:color_sort/color_sort.dart';
import 'package:puzzle_core/puzzle.dart';

/// 今の盤面から、最短の解の最初の1手を返す。見つからなければ null
/// (すでに詰んでいる・探索上限を超えた)。
typedef HintSolver = Future<Move?> Function(Board board);

/// 盤面を、ソルバーに渡せる spec(レベルと同じ形)に戻す。
Map<String, Object?> boardToSpec(Board b) => {
      'capacity': ColorSortRules.capacity,
      'tubes': [for (final t in b.tubes) List<int>.of(t)],
      if (b.hasLocks) 'locks': [for (final l in b.locks) l?.toJson()],
    };

Move? solveHint(Board board) {
  final r = solve(
    const ColorSortRules(),
    boardToSpec(board),
    maxStates: levelSolveMaxStates,
  );
  final s = r.solution;
  return s == null || s.isEmpty ? null : s.first;
}

/// 既定: 重い探索で画面が固まらないよう、別 isolate で解く。
Future<Move?> isolateHintSolver(Board board) {
  final spec = boardToSpec(board);
  return Isolate.run(() {
    final r =
        solve(const ColorSortRules(), spec, maxStates: levelSolveMaxStates);
    final s = r.solution;
    return s == null || s.isEmpty ? null : s.first;
  });
}
