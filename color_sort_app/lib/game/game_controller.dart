import 'package:color_sort/color_sort.dart';
import 'package:flutter/foundation.dart';
import 'package:puzzle_core/puzzle.dart';
import 'package:puzzle_core/foundation.dart';

/// 手が通らなかった理由(失敗の理由を見せるため)。
enum MoveError { locked, full, color, done }

/// 1面ぶんのプレイ状態。盤面ルールは [ColorSortRules] に任せる。
class GameController extends ChangeNotifier {
  GameController(this.level) : board = _rules.initial(level.spec);

  static const _rules = ColorSortRules();

  final LevelEntry level;
  Board board;
  int moves = 0;
  int? selected;
  MoveError? lastError;
  final List<Board> _history = [];

  bool get won => _rules.isWon(board);
  bool get stuck => !won && _rules.isLost(board);
  bool get canUndo => _history.isNotEmpty;

  /// クリア時の星(最短手数は同梱の検証結果から)。
  int? get stars {
    if (!won) return null;
    final min = level.verified?.minMoves;
    return min == null ? 1 : starsFor(moves, min);
  }

  void tap(int i) {
    if (won) return;
    lastError = null;
    final from = selected;
    if (from == null) {
      _trySelect(i);
    } else if (from == i) {
      selected = null;
    } else if (_rules.legalMoves(board).contains((from, i))) {
      _history.add(board);
      board = _rules.apply(board, (from, i));
      moves++;
      selected = null;
    } else {
      lastError = reasonFor(from, i);
      // 別の動かせる容器なら選び直し。
      if (board.tubes[i].isNotEmpty && board.isUsable(i)) {
        selected = i;
      }
    }
    notifyListeners();
  }

  void _trySelect(int i) {
    if (board.tubes[i].isEmpty) {
      return;
    }
    if (!board.isUsable(i)) {
      lastError = MoveError.locked;
    } else if (ColorSortRules.isDone(board.tubes[i])) {
      lastError = MoveError.done;
    } else {
      selected = i;
    }
  }

  MoveError reasonFor(int from, int to) {
    if (!board.isUsable(from) || !board.isUsable(to)) return MoveError.locked;
    if (ColorSortRules.isDone(board.tubes[from])) return MoveError.done;
    if (board.tubes[to].length >= ColorSortRules.capacity) {
      return MoveError.full;
    }
    return MoveError.color;
  }

  void undo() {
    if (_history.isEmpty) return;
    board = _history.removeLast();
    moves--;
    selected = null;
    lastError = null;
    notifyListeners();
  }

  void restart() {
    board = _rules.initial(level.spec);
    _history.clear();
    moves = 0;
    selected = null;
    lastError = null;
    notifyListeners();
  }
}
