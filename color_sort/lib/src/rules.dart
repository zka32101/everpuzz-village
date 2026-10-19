import 'package:puzzle_core/puzzle.dart';

/// 容器の並び(下→上)。色は 0..N-1 の整数。
typedef Tubes = List<List<int>>;

/// (移し元, 移し先)
typedef Move = (int from, int to);

enum LockKind {
  /// 鍵付き: 指定色が1本そろうまで使えない。
  key,

  /// 凍結: 隣の容器がそろうまで使えない。
  frozen,
}

class TubeLock {
  const TubeLock.key(int this.color) : kind = LockKind.key;

  const TubeLock.frozen()
      : kind = LockKind.frozen,
        color = null;

  factory TubeLock.fromJson(Map<String, Object?> j) =>
      switch (j['kind']! as String) {
        'key' => TubeLock.key(j['color']! as int),
        'frozen' => const TubeLock.frozen(),
        final k => throw FormatException('未知の容器種別: $k'),
      };

  final LockKind kind;

  /// key のときの解錠色。
  final int? color;

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        if (color != null) 'color': color,
      };

  @override
  String toString() => kind == LockKind.key ? 'key($color)' : 'frozen';
}

/// 盤面。[locks] は容器と同じ長さで、通常の容器は null(解けても状態は変わらない固定情報)。
class Board {
  const Board(this.tubes, this.locks);

  final Tubes tubes;
  final List<TubeLock?> locks;

  bool get hasLocks => locks.any((l) => l != null);

  /// 凍結があると容器の位置(隣り合い)が意味を持つ。鍵だけなら位置は無関係。
  bool get hasFrozen => locks.any((l) => l?.kind == LockKind.frozen);

  /// 容器 [i] が今使えるか。解錠・解凍は盤面から導ける(状態を別に持たない)。
  bool isUsable(int i) {
    final l = locks[i];
    if (l == null) return true;
    switch (l.kind) {
      case LockKind.key:
        return tubes.any((t) => ColorSortRules.isDone(t) && t.first == l.color);
      case LockKind.frozen:
        return (i > 0 && ColorSortRules.isDone(tubes[i - 1])) ||
            (i < tubes.length - 1 && ColorSortRules.isDone(tubes[i + 1]));
    }
  }
}

/// 色ソートのルール。容器に同色の塊を移し替え、1本1色にそろえる。
/// spec: `{"capacity": 4, "tubes": [[0,1,0,1], ..., []], "locks": [null, {"kind":"key","color":2}, ...]}`
/// (`locks` は省略可。特殊容器がない面では書かない)
class ColorSortRules extends PuzzleRules<Board, Move> {
  const ColorSortRules();

  /// 容器のスロット数(全面共通)。可変にする時は Board に持たせる。
  static const capacity = 4;

  @override
  Board initial(Map<String, Object?> spec) {
    final tubes = [
      for (final t in spec['tubes']! as List<Object?>)
        List<int>.from(t! as List),
    ];
    final rawLocks = spec['locks'] as List<Object?>?;
    final locks = [
      for (var i = 0; i < tubes.length; i++)
        rawLocks == null || rawLocks[i] == null
            ? null
            : TubeLock.fromJson(Map<String, Object?>.from(rawLocks[i]! as Map)),
    ];
    return Board(tubes, locks);
  }

  @override
  List<Move> legalMoves(Board s) {
    final tubes = s.tubes;
    final special = s.hasLocks;
    final positional = s.hasFrozen;
    final moves = <Move>[];
    for (var a = 0; a < tubes.length; a++) {
      final src = tubes[a];
      if (src.isEmpty || isDone(src)) continue; // 完成した容器は動かさない
      if (special && !s.isUsable(a)) continue;
      for (var b = 0; b < tubes.length; b++) {
        if (a == b || tubes[b].length >= capacity) continue;
        if (special && !s.isUsable(b)) continue;
        if (tubes[b].isEmpty) {
          // 単色の容器を空へ移すのは状態が同型なので除外。
          // 位置が意味を持つ(凍結)面や、特殊容器どうしでは除外しない。
          if (!positional &&
              s.locks[a] == null &&
              s.locks[b] == null &&
              src.toSet().length == 1) {
            continue;
          }
          moves.add((a, b));
        } else if (tubes[b].last == src.last) {
          moves.add((a, b));
        }
      }
    }
    return moves;
  }

  @override
  Board apply(Board s, Move m) {
    final next = [for (final t in s.tubes) List<int>.from(t)];
    final color = next[m.$1].last;
    while (next[m.$1].isNotEmpty &&
        next[m.$1].last == color &&
        next[m.$2].length < capacity) {
      next[m.$2].add(next[m.$1].removeLast());
    }
    return Board(next, s.locks);
  }

  @override
  bool isWon(Board s) => s.tubes.every((t) => t.isEmpty || isDone(t));

  static bool isDone(List<int> t) =>
      t.length == capacity && t.every((c) => c == t.first);

  /// 容器の入れ替えは同一状態として扱う(探索を減らす)。鍵は容器の種類ごと
  /// 中身と一緒に並べ替える。凍結があるときだけ位置が意味を持つので順序のまま。
  @override
  String hash(Board s) {
    final parts = [
      for (var i = 0; i < s.tubes.length; i++)
        '${s.locks[i] ?? ''}:${s.tubes[i].join(',')}',
    ];
    if (!s.hasFrozen) parts.sort();
    return parts.join('|');
  }
}
