import 'package:puzzle_core/puzzle.dart';

/// 容器の並び(下→上)。色は 0..N-1 の整数。
typedef Tubes = List<List<int>>;

/// (移し元, 移し先)
typedef Move = (int from, int to);

/// 色ソートのルール。容器に同色の塊を移し替え、1本1色にそろえる。
/// spec: `{"capacity": 4, "tubes": [[0,1,0,1], ..., []]}`
class ColorSortRules extends PuzzleRules<Tubes, Move> {
  const ColorSortRules();

  static int capacityOf(Map<String, Object?> spec) =>
      (spec['capacity'] as int?) ?? 4;

  @override
  Tubes initial(Map<String, Object?> spec) => [
        for (final t in spec['tubes']! as List<Object?>)
          List<int>.from(t! as List),
      ];

  // 容量は状態に持たない(全面共通の4)。可変にする時は State 型を導入する。
  static const capacity = 4;

  @override
  List<Move> legalMoves(Tubes s) {
    final moves = <Move>[];
    for (var a = 0; a < s.length; a++) {
      final src = s[a];
      if (src.isEmpty || _isDone(src)) continue; // 完成した容器は動かさない
      for (var b = 0; b < s.length; b++) {
        if (a == b || s[b].length >= capacity) continue;
        if (s[b].isEmpty) {
          // 単色の容器を空へ移すのは無意味(状態が同型)なので除外。
          if (src.toSet().length == 1) continue;
          moves.add((a, b));
        } else if (s[b].last == src.last) {
          moves.add((a, b));
        }
      }
    }
    return moves;
  }

  @override
  Tubes apply(Tubes s, Move m) {
    final next = [for (final t in s) List<int>.from(t)];
    final color = next[m.$1].last;
    while (next[m.$1].isNotEmpty &&
        next[m.$1].last == color &&
        next[m.$2].length < capacity) {
      next[m.$2].add(next[m.$1].removeLast());
    }
    return next;
  }

  @override
  bool isWon(Tubes s) => s.every((t) => t.isEmpty || _isDone(t));

  static bool _isDone(List<int> t) =>
      t.length == capacity && t.every((c) => c == t.first);

  /// 容器の入れ替えは同一状態として扱う(探索を減らす)。
  @override
  String hash(Tubes s) {
    final parts = [for (final t in s) t.join(',')]..sort();
    return parts.join('|');
  }
}
